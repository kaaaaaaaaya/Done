import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: RoutineStore
    @EnvironmentObject private var settings: SettingsStore

    @State private var newRoutineTitle: String = ""
    @State private var showSettings = false
    @State private var window: NSWindow?

    var body: some View {
        ZStack {
            AppBackground(color: settings.backgroundColor)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            NavigationSplitView {
                sidebar
            } detail: {
                RoutineDetailView(routineID: store.selectedRoutineID)
            }
            .navigationSplitViewStyle(.balanced)
            .tint(Theme.accent)
        }
        .environment(\.colorScheme, settings.colorScheme)
        .preferredColorScheme(settings.colorScheme)
        .foregroundColor(settings.primaryTextColor)
        .overlay(
            WindowAccessor { window in
                self.window = window
                settings.apply(to: window)
            }
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
        )
        .onChange(of: settings.windowOpacity) { _ in
            settings.apply(to: window)
        }
        .onChange(of: settings.displayMode) { _ in
            settings.apply(to: window)
        }
        .onChange(of: settings.backgroundColor) { _ in
            settings.apply(to: window)
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button("Settings") { showSettings = true }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(onResetWindowPosition: {
                settings.resetWindowPosition()
                settings.apply(to: window)
            })
                .environmentObject(settings)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            TodaySummaryView(
                total: store.routines.count,
                done: store.completedCount(for: Date()),
                remaining: store.remainingCount(for: Date())
            )

            addRoutineSection

            Divider().opacity(0.4)

            List(selection: $store.selectedRoutineID) {
                ForEach(store.routines) { routine in
                    RoutineRowView(
                        routine: routine,
                        isCompleted: store.isCompleted(routine.id, date: Date()),
                        onToggle: { store.toggleCompletion(routine.id, date: Date()) },
                        onDelete: { store.deleteRoutine(routine.id) }
                    )
                    .tag(routine.id)
                }
                .onDelete(perform: deleteRoutine)
            }
            .listStyle(.sidebar)
        }
        .padding(12)
        .frame(minWidth: 280)
    }

    private var addRoutineSection: some View {
        HStack(spacing: 8) {
            AppTextField(
                placeholder: "New routine",
                text: $newRoutineTitle,
                onSubmit: addRoutine
            )
            .frame(height: 30)
            .frame(maxWidth: .infinity)
            Button("Add") {
                addRoutine()
            }
            .buttonStyle(.borderedProminent)
            .disabled(newRoutineTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func addRoutine() {
        let trimmed = newRoutineTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.addRoutine(title: trimmed)
        newRoutineTitle = ""
    }

    private func deleteRoutine(at offsets: IndexSet) {
        for index in offsets {
            let id = store.routines[index].id
            store.deleteRoutine(id)
        }
    }
}

struct TodaySummaryView: View {
    @EnvironmentObject private var settings: SettingsStore
    let total: Int
    let done: Int
    let remaining: Int

    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(done) / Double(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
            Text("\(remaining) remaining / \(total) total")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(settings.secondaryTextColor)
            ProgressView(value: progress)
                .tint(Theme.accent)
        }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(settings.cardBackgroundColor)
            )
    }
}

struct RoutineRowView: View {
    @EnvironmentObject private var settings: SettingsStore
    let routine: Routine
    let isCompleted: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isCompleted ? .green : settings.secondaryTextColor)
            }
            .buttonStyle(.plain)

            Text(routine.title)
                .lineLimit(1)
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(settings.secondaryTextColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

struct RoutineDetailView: View {
    @EnvironmentObject private var store: RoutineStore
    @EnvironmentObject private var settings: SettingsStore

    let routineID: UUID?

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    var body: some View {
        if let routineID, let routine = store.routine(for: routineID) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        AppTextField(
                            placeholder: "Routine title",
                            text: store.titleBinding(for: routineID)
                        )
                        .frame(height: 30)
                        .frame(maxWidth: .infinity)
                        Spacer()
                        Button("Delete") {
                            store.deleteRoutine(routineID)
                        }
                        .buttonStyle(.bordered)
                    }

                    Toggle("Completed today", isOn: store.completionBinding(for: routineID))
                        .toggleStyle(.switch)

                    if settings.streaksEnabled {
                        streakSection(for: routine)
                        RoutineCalendarView(routine: routine, calendar: Calendar.current)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("History tracking is off")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                            Text("Enable streaks in settings to see calendar history.")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(settings.secondaryTextColor)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(settings.cardBackgroundColor)
                        )
                    }
                }
                .padding(20)
            }
        } else {
            VStack(spacing: 12) {
                Text("Select a routine")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Text("Add one on the left to get started.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(settings.secondaryTextColor)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func streakSection(for routine: Routine) -> some View {
        if let streak = store.currentStreak(for: routine) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Current streak")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Text("\(streak.length) days")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("From \(dateFormatter.string(from: streak.start)) to \(dateFormatter.string(from: streak.end))")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(settings.secondaryTextColor)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(settings.cardBackgroundColor)
            )
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("No active streak")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Text("Complete today to start a new streak.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(settings.secondaryTextColor)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(settings.cardBackgroundColor)
            )
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    let onResetWindowPosition: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Settings")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .foregroundColor(settings.primaryTextColor)

            VStack(alignment: .leading, spacing: 12) {
                Text("Appearance")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))

                HStack {
                    Text("Opacity")
                        .frame(width: 80, alignment: .leading)
                    Slider(value: $settings.windowOpacity, in: 0.35...1.0, step: 0.01)
                    Text("\(Int(settings.windowOpacity * 100))%")
                        .frame(width: 50, alignment: .trailing)
                }

                Picker("Window", selection: $settings.displayMode) {
                    ForEach(DisplayMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text("Normal behaves like a standard window. Always on top keeps it above other windows.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(settings.secondaryTextColor)

                Button("Reset window position") {
                    onResetWindowPosition()
                }
                .buttonStyle(.bordered)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(settings.cardBackgroundColor)
            )

            VStack(alignment: .leading, spacing: 12) {
                Text("Colors")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))

                ColorPicker("Background", selection: $settings.backgroundColor, supportsOpacity: false)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Text color is chosen automatically for readability.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(settings.secondaryTextColor)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(settings.cardBackgroundColor)
            )

            VStack(alignment: .leading, spacing: 12) {
                Text("Habits")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))

                Toggle("Enable streak history", isOn: $settings.streaksEnabled)
                    .toggleStyle(.switch)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(settings.cardBackgroundColor)
            )

            Spacer()
        }
        .padding(20)
        .frame(width: 420)
        .preferredColorScheme(settings.colorScheme)
        .foregroundColor(settings.primaryTextColor)
        .background(
            AppBackground(color: settings.backgroundColor)
                .ignoresSafeArea()
        )
    }
}

struct AppTextField: NSViewRepresentable {
    @EnvironmentObject private var settings: SettingsStore
    let placeholder: String
    @Binding var text: String
    var onSubmit: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: text)
        field.placeholderString = placeholder
        field.isEditable = true
        field.isSelectable = true
        field.isBordered = true
        field.bezelStyle = .roundedBezel
        field.drawsBackground = true
        field.focusRingType = .none
        field.usesSingleLineMode = true
        field.lineBreakMode = .byTruncatingTail
        field.font = NSFont.systemFont(ofSize: 13)
        field.delegate = context.coordinator
        applyTheme(to: field)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        applyTheme(to: nsView)
    }

    private func applyTheme(to field: NSTextField) {
        field.textColor = SettingsStore.nsColor(from: settings.primaryTextColor)
        field.backgroundColor = SettingsStore.nsColor(from: settings.cardBackgroundColor)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        private var text: Binding<String>
        private var onSubmit: (() -> Void)?

        init(text: Binding<String>, onSubmit: (() -> Void)?) {
            self.text = text
            self.onSubmit = onSubmit
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                onSubmit?()
                return true
            }
            return false
        }
    }
}

struct AppBackground: View {
    let color: Color

    var body: some View {
        color
    }
}

enum Theme {
    static let accent = Color(red: 0.34, green: 0.71, blue: 0.63)
    static let base = Color(red: 0.11, green: 0.14, blue: 0.18)
    static let depth = Color(red: 0.06, green: 0.07, blue: 0.1)
}
