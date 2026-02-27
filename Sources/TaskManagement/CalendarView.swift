import SwiftUI

enum DayStatus {
    case completed
    case missed
    case future
    case beforeCreated
}

struct RoutineCalendarView: View {
    @EnvironmentObject private var settings: SettingsStore
    let routine: Routine
    let calendar: Calendar

    @State private var monthOffset: Int = 0

    private var monthDate: Date {
        let today = Date()
        let start = calendar.startOfMonth(for: today)
        return calendar.date(byAdding: .month, value: monthOffset, to: start) ?? today
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            weekdayHeader
            calendarGrid
            legend
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(settings.cardBackgroundColor)
        )
    }

    private var header: some View {
        HStack {
            Text(monthTitle(for: monthDate))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
            Spacer()
            Button(action: { monthOffset -= 1 }) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            Button(action: { monthOffset += 1 }) {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
        }
    }

    private var weekdayHeader: some View {
        let symbols = reorderedWeekdaySymbols()
        return HStack(spacing: 6) {
            ForEach(symbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(settings.secondaryTextColor)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var calendarGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
        let days = daysForMonth(monthDate)
        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(days, id: \.self) { day in
                if let dayDate = day.date {
                    let status = status(for: dayDate)
                    DayCellView(
                        day: calendar.component(.day, from: dayDate),
                        status: status,
                        isToday: calendar.isDateInToday(dayDate)
                    )
                } else {
                    Color.clear
                        .frame(height: 28)
                }
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 12) {
            legendItem(color: .green, label: "Done")
            legendItem(color: .red, label: "Missed")
            legendItem(color: .gray, label: "Future")
        }
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundColor(settings.secondaryTextColor)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
        }
    }

    private func monthTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }

    private func reorderedWeekdaySymbols() -> [String] {
        let symbols = calendar.shortWeekdaySymbols
        let index = max(calendar.firstWeekday - 1, 0)
        if index == 0 { return symbols }
        return Array(symbols[index...]) + symbols[..<index]
    }

    private struct DayEntry: Hashable {
        let date: Date?
    }

    private func daysForMonth(_ date: Date) -> [DayEntry] {
        let startOfMonth = calendar.startOfMonth(for: date)
        let range = calendar.range(of: .day, in: .month, for: startOfMonth) ?? 1..<2
        let daysInMonth = range.count
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7

        var entries: [DayEntry] = Array(repeating: DayEntry(date: nil), count: leading)
        for day in 0..<daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day, to: startOfMonth) {
                entries.append(DayEntry(date: date))
            }
        }
        return entries
    }

    private func status(for date: Date) -> DayStatus {
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)
        let created = calendar.startOfDay(for: routine.createdAt)

        if target < created {
            return .beforeCreated
        }
        if target > today {
            return .future
        }
        let key = DayKey.from(date: target, calendar: calendar)
        return routine.completions.contains(key) ? .completed : .missed
    }
}

struct DayCellView: View {
    @EnvironmentObject private var settings: SettingsStore
    let day: Int
    let status: DayStatus
    let isToday: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(backgroundColor)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(borderColor, lineWidth: isToday ? 2 : 1)
            Text("\(day)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(textColor)
        }
        .frame(height: 28)
    }

    private var backgroundColor: Color {
        switch status {
        case .completed:
            return Color.green.opacity(0.6)
        case .missed:
            return Color.red.opacity(0.2)
        case .future, .beforeCreated:
            return Color.clear
        }
    }

    private var borderColor: Color {
        switch status {
        case .completed:
            return Color.green
        case .missed:
            return Color.red
        case .future:
            return Color.gray.opacity(0.3)
        case .beforeCreated:
            return Color.gray.opacity(0.15)
        }
    }

    private var textColor: Color {
        switch status {
        case .completed, .missed:
            return settings.primaryTextColor
        case .future, .beforeCreated:
            return settings.secondaryTextColor
        }
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}
