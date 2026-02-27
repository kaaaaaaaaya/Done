import AppKit
import Foundation
import SwiftUI

enum DisplayMode: String, CaseIterable, Identifiable {
    case normal
    case floating

    var id: String { rawValue }

    var label: String {
        switch self {
        case .normal: return "Normal"
        case .floating: return "Always on top"
        }
    }

    var windowLevel: NSWindow.Level {
        switch self {
        case .normal: return .normal
        case .floating: return .floating
        }
    }
}

final class SettingsStore: ObservableObject {
    @Published var windowOpacity: Double {
        didSet { save() }
    }
    @Published var displayMode: DisplayMode {
        didSet { save() }
    }
    @Published var streaksEnabled: Bool {
        didSet { save() }
    }
    @Published var backgroundColor: Color {
        didSet { save() }
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let windowOpacity = "windowOpacity"
        static let displayMode = "displayMode"
        static let streaksEnabled = "streaksEnabled"
        static let hasPositionedWindow = "hasPositionedWindow"
        static let backgroundColor = "backgroundColor"
        static let displayModeMigrated = "displayModeMigrated"
    }

    init() {
        let storedOpacity = defaults.object(forKey: Keys.windowOpacity) as? Double
        windowOpacity = storedOpacity ?? 1.0

        let storedMode = defaults.string(forKey: Keys.displayMode)
        if storedMode == DisplayMode.floating.rawValue,
           defaults.object(forKey: Keys.displayModeMigrated) == nil {
            displayMode = .normal
            defaults.set(true, forKey: Keys.displayModeMigrated)
        } else {
            displayMode = DisplayMode(rawValue: storedMode ?? "") ?? .normal
        }

        let storedStreaks = defaults.object(forKey: Keys.streaksEnabled) as? Bool
        streaksEnabled = storedStreaks ?? true

        let storedBackground = defaults.string(forKey: Keys.backgroundColor)
        backgroundColor = SettingsStore.decodeColor(from: storedBackground)
            ?? Color(red: 0.11, green: 0.14, blue: 0.18)
    }

    func apply(to window: NSWindow?) {
        guard let window else { return }

        let nsBackground = SettingsStore.nsColor(from: backgroundColor)
        window.isOpaque = windowOpacity >= 0.999
        window.backgroundColor = nsBackground
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        window.isMovableByWindowBackground = false
        window.ignoresMouseEvents = false
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.minSize = NSSize(width: 720, height: 520)
        window.alphaValue = max(0.35, min(windowOpacity, 1.0))
        window.level = displayMode.windowLevel
        window.showsResizeIndicator = true
        window.appearance = (colorScheme == .dark)
            ? NSAppearance(named: .darkAqua)
            : NSAppearance(named: .aqua)
        if !window.isKeyWindow {
            window.makeKeyAndOrderFront(nil)
        }
        positionWindowIfNeeded(window)
    }

    func resetWindowPosition() {
        defaults.set(false, forKey: Keys.hasPositionedWindow)
    }

    private func positionWindowIfNeeded(_ window: NSWindow) {
        guard !defaults.bool(forKey: Keys.hasPositionedWindow) else { return }
        guard let screen = window.screen ?? NSScreen.main else { return }

        let padding: CGFloat = 24
        let visibleFrame = screen.visibleFrame
        let topLeft = CGPoint(x: visibleFrame.minX + padding, y: visibleFrame.maxY - padding)
        window.setFrameTopLeftPoint(topLeft)

        defaults.set(true, forKey: Keys.hasPositionedWindow)
    }

    private func save() {
        defaults.set(windowOpacity, forKey: Keys.windowOpacity)
        defaults.set(displayMode.rawValue, forKey: Keys.displayMode)
        defaults.set(streaksEnabled, forKey: Keys.streaksEnabled)
        defaults.set(SettingsStore.encodeColor(from: backgroundColor), forKey: Keys.backgroundColor)
    }

    var colorScheme: ColorScheme {
        let luminance = SettingsStore.relativeLuminance(for: backgroundColor)
        return luminance > 0.6 ? .light : .dark
    }

    var primaryTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    var secondaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.6)
    }

    var cardBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06)
    }

    private static func encodeColor(from color: Color) -> String {
        let nsColor = NSColor(color).usingColorSpace(.deviceRGB) ?? .black
        let r = Int(round(nsColor.redComponent * 255))
        let g = Int(round(nsColor.greenComponent * 255))
        let b = Int(round(nsColor.blueComponent * 255))
        let a = Int(round(nsColor.alphaComponent * 255))
        return String(format: "%02X%02X%02X%02X", r, g, b, a)
    }

    private static func decodeColor(from value: String?) -> Color? {
        guard let value, value.count == 8 else { return nil }
        let r = hexComponent(value, start: 0)
        let g = hexComponent(value, start: 2)
        let b = hexComponent(value, start: 4)
        let a = hexComponent(value, start: 6)
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    private static func hexComponent(_ value: String, start: Int) -> Double {
        let startIndex = value.index(value.startIndex, offsetBy: start)
        let endIndex = value.index(startIndex, offsetBy: 2)
        let substring = String(value[startIndex..<endIndex])
        let intValue = Int(substring, radix: 16) ?? 255
        return Double(intValue) / 255.0
    }

    private static func relativeLuminance(for color: Color) -> Double {
        let nsColor = nsColor(from: color)
        let r = nsColor.redComponent
        let g = nsColor.greenComponent
        let b = nsColor.blueComponent
        return 0.2126 * Double(r) + 0.7152 * Double(g) + 0.0722 * Double(b)
    }

    static func nsColor(from color: Color) -> NSColor {
        NSColor(color).usingColorSpace(.deviceRGB) ?? .black
    }
}
