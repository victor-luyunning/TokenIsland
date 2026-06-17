import Foundation

extension Double {
    var formattedCompactTokens: String {
        let absolute = abs(self)
        if absolute >= 1_000_000_000 {
            return String(format: "%.1fB", self / 1_000_000_000)
        }
        if absolute >= 1_000_000 {
            return String(format: "%.1fM", self / 1_000_000)
        }
        if absolute >= 1_000 {
            return String(format: "%.1fK", self / 1_000)
        }
        return String(format: "%.0f", self)
    }

    var formattedPercent: String {
        String(format: "%.1f%%", self * 100)
    }

    var formattedDollars: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = self >= 100 ? 0 : 2
        return formatter.string(from: NSNumber(value: self)) ?? String(format: "$%.2f", self)
    }
}

extension Date {
    var shortTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"
        return formatter.string(from: self)
    }

    var shortDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: self)
    }
}
