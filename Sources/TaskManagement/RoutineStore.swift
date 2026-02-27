import Foundation
import SwiftUI

struct Routine: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var createdAt: Date
    var completions: Set<String>
}

struct StreakInfo: Hashable {
    let start: Date
    let end: Date
    let length: Int
}

enum DayKey {
    static func from(date: Date, calendar: Calendar = Calendar.current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func date(from key: String, calendar: Calendar = Calendar.current) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        let components = DateComponents(year: parts[0], month: parts[1], day: parts[2])
        return calendar.date(from: components)
    }
}

final class RoutineStore: ObservableObject {
    @Published private(set) var routines: [Routine] = []
    @Published var selectedRoutineID: UUID?

    private let calendar: Calendar
    private let fileURL: URL

    init(calendar: Calendar = Calendar.current) {
        self.calendar = calendar
        self.fileURL = RoutineStore.defaultFileURL()
        load()
        if selectedRoutineID == nil {
            selectedRoutineID = routines.first?.id
        }
    }

    func routine(for id: UUID) -> Routine? {
        routines.first { $0.id == id }
    }

    func addRoutine(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let routine = Routine(id: UUID(), title: trimmed, createdAt: Date(), completions: [])
        routines.insert(routine, at: 0)
        selectedRoutineID = routine.id
        save()
    }

    func deleteRoutine(_ id: UUID) {
        routines.removeAll { $0.id == id }
        if selectedRoutineID == id {
            selectedRoutineID = routines.first?.id
        }
        save()
    }

    func updateRoutineTitle(_ id: UUID, _ title: String) {
        guard let index = routines.firstIndex(where: { $0.id == id }) else { return }
        routines[index].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        save()
    }

    func toggleCompletion(_ id: UUID, date: Date = Date()) {
        setCompletion(id, date: date, completed: !isCompleted(id, date: date))
    }

    func setCompletion(_ id: UUID, date: Date = Date(), completed: Bool) {
        guard let index = routines.firstIndex(where: { $0.id == id }) else { return }
        let key = DayKey.from(date: date, calendar: calendar)
        if completed {
            routines[index].completions.insert(key)
        } else {
            routines[index].completions.remove(key)
        }
        save()
    }

    func isCompleted(_ id: UUID, date: Date = Date()) -> Bool {
        guard let routine = routine(for: id) else { return false }
        let key = DayKey.from(date: date, calendar: calendar)
        return routine.completions.contains(key)
    }

    func completedCount(for date: Date = Date()) -> Int {
        routines.filter { routine in
            routine.completions.contains(DayKey.from(date: date, calendar: calendar))
        }.count
    }

    func remainingCount(for date: Date = Date()) -> Int {
        max(routines.count - completedCount(for: date), 0)
    }

    func currentStreak(for routine: Routine, today: Date = Date()) -> StreakInfo? {
        let todayKey = DayKey.from(date: today, calendar: calendar)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let yesterdayKey = DayKey.from(date: yesterday, calendar: calendar)

        let endDate: Date
        if routine.completions.contains(todayKey) {
            endDate = calendar.startOfDay(for: today)
        } else if routine.completions.contains(yesterdayKey) {
            endDate = calendar.startOfDay(for: yesterday)
        } else {
            return nil
        }

        var startDate = endDate
        var length = 1

        while true {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: startDate) else { break }
            let previousKey = DayKey.from(date: previous, calendar: calendar)
            if routine.completions.contains(previousKey) {
                startDate = calendar.startOfDay(for: previous)
                length += 1
            } else {
                break
            }
        }

        return StreakInfo(start: startDate, end: endDate, length: length)
    }

    func completionBinding(for id: UUID, date: Date = Date()) -> Binding<Bool> {
        Binding(
            get: { [weak self] in
                self?.isCompleted(id, date: date) ?? false
            },
            set: { [weak self] newValue in
                self?.setCompletion(id, date: date, completed: newValue)
            }
        )
    }

    func titleBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { [weak self] in
                self?.routine(for: id)?.title ?? ""
            },
            set: { [weak self] newValue in
                self?.updateRoutineTitle(id, newValue)
            }
        )
    }

    private func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode([Routine].self, from: data)
            routines = decoded
        } catch {
            routines = []
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            let data = try JSONEncoder().encode(routines)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // Intentionally ignore save errors to keep UI responsive.
        }
    }

    private static func defaultFileURL() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return appSupport
            .appendingPathComponent("TaskManagement", isDirectory: true)
            .appendingPathComponent("routines.json")
    }
}
