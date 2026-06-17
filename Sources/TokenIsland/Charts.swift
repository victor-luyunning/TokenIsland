import SwiftUI

struct LineChart: View {
    let points: [HourlyPoint]
    let accent: Color

    private var maxValue: Double {
        max(points.map(\.tokens).max() ?? 0, 1)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let normalized = normalizedPoints(in: size)

            ZStack {
                GridLines()
                    .stroke(Color.white.opacity(0.075), lineWidth: 1)

                fillPath(points: normalized, size: size)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.30), accent.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                linePath(points: normalized)
                    .stroke(accent, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .shadow(color: accent.opacity(0.28), radius: 8, y: 4)

                if let last = normalized.last {
                    Circle()
                        .fill(accent)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.white.opacity(0.55), lineWidth: 2))
                        .position(last)
                }
            }
        }
        .frame(height: 116)
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        let chartWidth = max(size.width, 1)
        let chartHeight = max(size.height, 1)

        return points.map { point in
            let x = CGFloat(point.hour) / 23 * chartWidth
            let ratio = CGFloat(point.tokens / maxValue)
            let y = chartHeight - (ratio * chartHeight * 0.88) - chartHeight * 0.06
            return CGPoint(x: x, y: y)
        }
    }

    private func linePath(points: [CGPoint]) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)

            for index in 1..<points.count {
                let previous = points[index - 1]
                let current = points[index]
                let midX = (previous.x + current.x) / 2
                path.addCurve(
                    to: current,
                    control1: CGPoint(x: midX, y: previous.y),
                    control2: CGPoint(x: midX, y: current.y)
                )
            }
        }
    }

    private func fillPath(points: [CGPoint], size: CGSize) -> Path {
        Path { path in
            guard let first = points.first, let last = points.last else { return }
            path.move(to: CGPoint(x: first.x, y: size.height))
            path.addLine(to: first)

            for index in 1..<points.count {
                let previous = points[index - 1]
                let current = points[index]
                let midX = (previous.x + current.x) / 2
                path.addCurve(
                    to: current,
                    control1: CGPoint(x: midX, y: previous.y),
                    control2: CGPoint(x: midX, y: current.y)
                )
            }

            path.addLine(to: CGPoint(x: last.x, y: size.height))
            path.closeSubpath()
        }
    }
}

private struct GridLines: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            for row in 0...3 {
                let y = rect.minY + rect.height * CGFloat(row) / 3
                path.move(to: CGPoint(x: rect.minX, y: y))
                path.addLine(to: CGPoint(x: rect.maxX, y: y))
            }

            for column in stride(from: 0, through: 24, by: 3) {
                let x = rect.minX + rect.width * CGFloat(column) / 24
                path.move(to: CGPoint(x: x, y: rect.minY))
                path.addLine(to: CGPoint(x: x, y: rect.maxY))
            }
        }
    }
}

struct WeeklyBars: View {
    let days: [DailyPoint]
    let accent: Color
    let onSelect: (Date) -> Void

    private var maxValue: Double {
        max(days.map(\.tokens).max() ?? 0, 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ForEach(days) { day in
                Button {
                    onSelect(day.date)
                } label: {
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(day.isToday ? accent : accent.opacity(day.isSelected ? 0.55 : 0.28))
                            .frame(height: max(8, CGFloat(day.tokens / maxValue) * 52))
                            .overlay {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .strokeBorder(day.isSelected ? Color.white.opacity(0.64) : Color.clear, lineWidth: 1)
                            }
                        Text(day.weekday)
                            .font(.system(size: 10, weight: day.isSelected ? .bold : .medium))
                            .foregroundStyle(day.isSelected ? Color.white.opacity(0.88) : Color.white.opacity(0.48))
                            .frame(height: 12)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .opacity(day.isSelected || day.isToday ? 1.0 : 0.9)
            }
        }
        .frame(height: 72)
    }
}
