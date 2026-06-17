import Foundation

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshot = UsageSnapshot()
    @Published var selectedDate = Calendar.current.startOfDay(for: Date())

    private let databasePath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".cc-switch/cc-switch.db")
        .path

    func refresh() {
        let selectedDate = selectedDate
        let databasePath = databasePath
        Task.detached(priority: .utility) {
            let reader = UsageReader(databasePath: databasePath, focusDate: selectedDate, weekAnchorDate: Date())
            let nextSnapshot = reader.loadSnapshot()
            await MainActor.run {
                self.snapshot = nextSnapshot
            }
        }
    }

    func selectDate(_ date: Date) {
        selectedDate = Calendar.current.startOfDay(for: date)
        refresh()
    }
}

struct UsageReader {
    let databasePath: String
    let focusDate: Date
    let weekAnchorDate: Date

    func loadSnapshot() -> UsageSnapshot {
        guard FileManager.default.fileExists(atPath: databasePath) else {
            var snapshot = UsageSnapshot()
            snapshot.errorMessage = "CC Switch database not found"
            snapshot.daily = makeEmptyDaily()
            snapshot.focusDate = focusDate
            return snapshot
        }

        do {
            let calendar = Calendar.current
            let focusStart = calendar.startOfDay(for: focusDate)
            let focusEnd = calendar.date(byAdding: .day, value: 1, to: focusStart) ?? focusStart
            let todayStart = calendar.startOfDay(for: weekAnchorDate)
            let weekStart = calendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart

            let todayRows = try query("""
                with normalized as (
                  select
                    case
                      when input_tokens >= cache_read_tokens + cache_creation_tokens
                      then input_tokens - cache_read_tokens - cache_creation_tokens
                      else input_tokens
                    end as new_input_tokens,
                    output_tokens,
                    cache_read_tokens,
                    cache_creation_tokens,
                    total_cost_usd
                  from proxy_request_logs
                  where created_at >= \(Int(focusStart.timeIntervalSince1970))
                    and created_at < \(Int(focusEnd.timeIntervalSince1970))
                )
                select
                  coalesce(sum(new_input_tokens + output_tokens + cache_read_tokens + cache_creation_tokens), 0),
                  coalesce(sum(cast(total_cost_usd as real)), 0),
                  coalesce(sum(new_input_tokens), 0),
                  coalesce(sum(output_tokens), 0),
                  coalesce(sum(cache_read_tokens), 0),
                  coalesce(sum(cache_creation_tokens), 0),
                  count(*)
                from normalized;
                """)

            let todayTokens = todayRows.first?.double(at: 0) ?? 0
            let todayCost = todayRows.first?.double(at: 1) ?? 0
            let inputTokens = todayRows.first?.double(at: 2) ?? 0
            let outputTokens = todayRows.first?.double(at: 3) ?? 0
            let cacheReadTokens = todayRows.first?.double(at: 4) ?? 0
            let cacheCreationTokens = todayRows.first?.double(at: 5) ?? 0
            let requestCount = todayRows.first?.int(at: 6) ?? 0

            let hourly = try loadHourly(from: focusStart, to: focusEnd)
            let models = try loadModels(from: focusStart, to: focusEnd, todayTokens: todayTokens)
            let types = try loadTypes(from: focusStart, to: focusEnd, todayTokens: todayTokens)
            let daily = try loadDaily(from: weekStart, through: focusStart)

            return UsageSnapshot(
                focusDate: focusStart,
                todayTokens: todayTokens,
                todayCost: todayCost,
                cacheRatio: (inputTokens + cacheReadTokens + cacheCreationTokens) > 0 ? cacheReadTokens / (inputTokens + cacheReadTokens + cacheCreationTokens) : 0,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                cacheReadTokens: cacheReadTokens,
                cacheCreationTokens: cacheCreationTokens,
                requestCount: requestCount,
                lastUpdated: Date(),
                hourly: hourly,
                models: models.isEmpty ? [ModelUsage(name: "No usage yet", tokens: 0, cost: 0, share: 0)] : models,
                types: types,
                daily: daily,
                errorMessage: nil
            )
        } catch {
            var snapshot = UsageSnapshot()
            snapshot.errorMessage = error.localizedDescription
            snapshot.daily = makeEmptyDaily()
            snapshot.focusDate = focusDate
            return snapshot
        }
    }

    private func loadHourly(from start: Date, to end: Date) throws -> [HourlyPoint] {
        let rows = try query("""
            select cast(strftime('%H', created_at, 'unixepoch', 'localtime') as integer) as hour,
                   coalesce(sum(
                     case
                       when input_tokens >= cache_read_tokens + cache_creation_tokens
                       then input_tokens - cache_read_tokens - cache_creation_tokens
                       else input_tokens
                     end + output_tokens + cache_read_tokens + cache_creation_tokens
                   ), 0)
            from proxy_request_logs
            where created_at >= \(Int(start.timeIntervalSince1970))
              and created_at < \(Int(end.timeIntervalSince1970))
            group by hour
            order by hour;
            """)

        var buckets = Dictionary(uniqueKeysWithValues: (0..<24).map { ($0, 0.0) })
        for row in rows {
            buckets[row.int(at: 0)] = row.double(at: 1)
        }

        return (0..<24).map { HourlyPoint(hour: $0, tokens: buckets[$0] ?? 0) }
    }

    private func loadModels(from start: Date, to end: Date, todayTokens: Double) throws -> [ModelUsage] {
        let rows = try query("""
            select model,
                   coalesce(sum(
                     case
                       when input_tokens >= cache_read_tokens + cache_creation_tokens
                       then input_tokens - cache_read_tokens - cache_creation_tokens
                       else input_tokens
                     end + output_tokens + cache_read_tokens + cache_creation_tokens
                   ), 0) as tokens,
                   coalesce(sum(cast(total_cost_usd as real)), 0) as cost
            from proxy_request_logs
            where created_at >= \(Int(start.timeIntervalSince1970))
              and created_at < \(Int(end.timeIntervalSince1970))
            group by model
            order by tokens desc
            limit 6;
            """)

        return rows.map { row in
            let tokens = row.double(at: 1)
            return ModelUsage(
                name: row.string(at: 0),
                tokens: tokens,
                cost: row.double(at: 2),
                share: todayTokens > 0 ? tokens / todayTokens : 0
            )
        }
    }

    private func loadTypes(from start: Date, to end: Date, todayTokens: Double) throws -> [TypeUsage] {
        let rows = try query("""
            select
              coalesce(sum(case
                when input_tokens >= cache_read_tokens + cache_creation_tokens
                then input_tokens - cache_read_tokens - cache_creation_tokens
                else input_tokens
              end), 0),
              coalesce(sum(output_tokens), 0),
              coalesce(sum(cache_read_tokens), 0)
            from proxy_request_logs
            where created_at >= \(Int(start.timeIntervalSince1970))
              and created_at < \(Int(end.timeIntervalSince1970));
            """)

        let row = rows.first
        let input = row?.double(at: 0) ?? 0
        let output = row?.double(at: 1) ?? 0
        let cacheRead = row?.double(at: 2) ?? 0

        return [
            TypeUsage(name: "New Input", tokens: input, share: todayTokens > 0 ? input / todayTokens : 0),
            TypeUsage(name: "Output", tokens: output, share: todayTokens > 0 ? output / todayTokens : 0),
            TypeUsage(name: "Cache Hit", tokens: cacheRead, share: todayTokens > 0 ? cacheRead / todayTokens : 0)
        ]
    }

    private func loadDaily(from weekStart: Date, through todayStart: Date) throws -> [DailyPoint] {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart

        let rows = try query("""
            select date(created_at, 'unixepoch', 'localtime') as day,
                   coalesce(sum(
                     case
                       when input_tokens >= cache_read_tokens + cache_creation_tokens
                       then input_tokens - cache_read_tokens - cache_creation_tokens
                       else input_tokens
                     end + output_tokens + cache_read_tokens + cache_creation_tokens
                   ), 0)
            from proxy_request_logs
            where created_at >= \(Int(weekStart.timeIntervalSince1970))
              and created_at < \(Int(tomorrow.timeIntervalSince1970))
            group by day
            order by day;
            """)

        var totals: [String: Double] = [:]
        for row in rows {
            totals[row.string(at: 0)] = row.double(at: 1)
        }

        let keyFormatter = DateFormatter()
        keyFormatter.calendar = calendar
        keyFormatter.locale = Locale(identifier: "en_US_POSIX")
        keyFormatter.dateFormat = "yyyy-MM-dd"

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else {
                return nil
            }
            let key = keyFormatter.string(from: date)
            return DailyPoint(
                date: date,
                tokens: totals[key] ?? 0,
                isSelected: calendar.isDate(date, inSameDayAs: focusDate),
                isToday: calendar.isDate(date, inSameDayAs: Date())
            )
        }
    }

    private func makeEmptyDaily() -> [DailyPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else {
                return nil
            }
            return DailyPoint(
                date: date,
                tokens: 0,
                isSelected: calendar.isDate(date, inSameDayAs: focusDate),
                isToday: calendar.isDate(date, inSameDayAs: today)
            )
        }
    }

    private func query(_ sql: String) throws -> [SQLiteRow] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = ["-readonly", "-separator", "\u{1f}", databasePath, sql]

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error

        try process.run()
        process.waitUntilExit()

        let errorData = error.fileHandleForReading.readDataToEndOfFile()
        if process.terminationStatus != 0 {
            let message = String(data: errorData, encoding: .utf8) ?? "sqlite3 failed"
            throw NSError(domain: "TokenIsland.SQLite", code: Int(process.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: message.trimmingCharacters(in: .whitespacesAndNewlines)
            ])
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8) ?? ""
        return text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { line in
                SQLiteRow(fields: line.split(separator: "\u{1f}", omittingEmptySubsequences: false).map(String.init))
            }
    }
}

struct SQLiteRow {
    let fields: [String]

    func string(at index: Int) -> String {
        guard fields.indices.contains(index) else { return "" }
        return fields[index]
    }

    func double(at index: Int) -> Double {
        Double(string(at: index)) ?? 0
    }

    func int(at index: Int) -> Int {
        Int(double(at: index))
    }
}
