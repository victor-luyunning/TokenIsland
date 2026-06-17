import Foundation

struct UsageSnapshot {
    var focusDate: Date = Date()
    var todayTokens: Double = 0
    var todayCost: Double = 0
    var cacheRatio: Double = 0
    var inputTokens: Double = 0
    var outputTokens: Double = 0
    var cacheReadTokens: Double = 0
    var cacheCreationTokens: Double = 0
    var requestCount: Int = 0
    var lastUpdated: Date = Date()
    var hourly: [HourlyPoint] = HourlyPoint.emptyDay
    var models: [ModelUsage] = []
    var types: [TypeUsage] = []
    var daily: [DailyPoint] = []
    var errorMessage: String?
}

struct HourlyPoint: Identifiable {
    let hour: Int
    let tokens: Double

    var id: Int { hour }

    static var emptyDay: [HourlyPoint] {
        (0..<24).map { HourlyPoint(hour: $0, tokens: 0) }
    }
}

struct ModelUsage: Identifiable {
    let name: String
    let tokens: Double
    let cost: Double
    let share: Double

    var id: String { name }
}

struct TypeUsage: Identifiable {
    let name: String
    let tokens: Double
    let share: Double

    var id: String { name }
}

struct DailyPoint: Identifiable {
    let date: Date
    let tokens: Double
    let isSelected: Bool
    let isToday: Bool

    var id: Date { date }

    var weekday: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}
