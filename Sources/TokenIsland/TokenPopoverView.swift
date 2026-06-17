import SwiftUI

struct TokenPopoverView: View {
    @ObservedObject var store: UsageStore
    @State private var usageMode: UsageMode = .model

    private let accent = Color(red: 0.28, green: 0.86, blue: 0.69)
    private let blueAccent = Color(red: 0.22, green: 0.58, blue: 1.0)

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 22)
                    .padding(.top, 20)
                    .padding(.bottom, 14)

                Divider().overlay(Color.white.opacity(0.10))

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 17) {
                        hourlySection
                        usageSection
                        weeklySection
                        cacheSection
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 18)
                }

                Divider().overlay(Color.white.opacity(0.10))

                footer
            }
        }
        .frame(width: 360, height: 520)
        .preferredColorScheme(.dark)
    }

    private var snapshot: UsageSnapshot {
        store.snapshot
    }

    private var selectedDateString: String {
        snapshot.focusDate.shortDateString
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(snapshot.todayTokens.formattedCompactTokens)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                HStack(spacing: 6) {
                    Text(selectedDateString)
                    Text("·")
                    Text(snapshot.lastUpdated.shortTimeString)
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.48))
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 9) {
                Text(snapshot.todayCost.formattedDollars)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                HStack(spacing: 7) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 10, weight: .bold))
                    Text("cache \(snapshot.cacheRatio.formattedPercent)")
                }
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(accent)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(accent.opacity(0.13), in: Capsule())
            }
        }
        .overlay(alignment: .bottomLeading) {
            if let error = snapshot.errorMessage {
                Text(error)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.orange.opacity(0.92))
                    .lineLimit(1)
                    .offset(y: 18)
            }
        }
    }

    private var hourlySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Hourly")
            LineChart(points: snapshot.hourly, accent: accent)

            HStack {
                ForEach([0, 3, 6, 9, 12, 15, 18, 21], id: \.self) { hour in
                    Text("\(hour)")
                        .font(.system(size: 10, weight: hour == Calendar.current.component(.hour, from: Date()) ? .bold : .medium))
                        .foregroundStyle(hour == Calendar.current.component(.hour, from: Date()) ? accent : Color.white.opacity(0.38))
                        .frame(maxWidth: .infinity)
                }
            }
            .offset(y: -4)
        }
    }

    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                SectionTitle("Usage")
                Spacer()
                Picker("", selection: $usageMode) {
                    Text("By Model").tag(UsageMode.model)
                    Text("By Type").tag(UsageMode.type)
                }
                .pickerStyle(.segmented)
                .frame(width: 154)
                .controlSize(.small)
            }

            VStack(spacing: 9) {
                if usageMode == .model {
                    ForEach(snapshot.models.prefix(4)) { item in
                        UsageRow(
                            title: item.name,
                            value: item.tokens.formattedCompactTokens,
                            percent: item.share.formattedPercent,
                            progress: item.share,
                            color: accent
                        )
                    }
                } else {
                    ForEach(snapshot.types) { item in
                        UsageRow(
                            title: item.name,
                            value: item.tokens.formattedCompactTokens,
                            percent: item.share.formattedPercent,
                            progress: item.share,
                            color: blueAccent
                        )
                    }
                }
            }
        }
    }

    private var weeklySection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                SectionTitle("7-Day Tokens")
                Spacer()
                let weekTotal = snapshot.daily.reduce(0) { $0 + $1.tokens }
                Text("\(weekTotal.formattedCompactTokens) wk · \((weekTotal / 7).formattedCompactTokens)/day")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.48))
            }

            WeeklyBars(days: snapshot.daily, accent: accent) { date in
                store.selectDate(date)
            }
        }
    }

    private var cacheSection: some View {
        FrostedCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 7) {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("Cache Hit")
                    }
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.70))

                    Spacer()

                    Text(snapshot.cacheRatio.formattedPercent)
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(accent)
                }

                ProgressView(value: min(max(snapshot.cacheRatio, 0), 1))
                    .tint(accent)
                    .scaleEffect(x: 1, y: 0.75)

                HStack {
                    Text("CC Switch formula")
                    Spacer()
                    Text("hit / (new + hit)")
                }
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.36))
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 0) {
            Button {
                store.refresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }

            Divider().frame(height: 28).overlay(Color.white.opacity(0.10))

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.plain)
        .font(.system(size: 12, weight: .bold, design: .rounded))
        .foregroundStyle(Color.white.opacity(0.58))
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }
}

private enum UsageMode {
    case model
    case type
}

private struct SectionTitle: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .tracking(1.1)
            .foregroundStyle(Color.white.opacity(0.48))
    }
}

private struct UsageRow: View {
    let title: String
    let value: String
    let percent: String
    let progress: Double
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)

            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.66))
                .lineLimit(1)
                .frame(width: 86, alignment: .leading)

            ProgressView(value: min(max(progress, 0), 1))
                .tint(color)
                .frame(maxWidth: .infinity)
                .scaleEffect(x: 1, y: 0.62)

            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.90))
                .frame(width: 48, alignment: .trailing)

            Text(percent)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.38))
                .frame(width: 42, alignment: .trailing)
        }
    }
}
