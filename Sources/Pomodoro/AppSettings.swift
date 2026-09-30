import AppKit
import Combine
import Foundation

/// UserDefaults に自動保存される設定。
final class AppSettings: ObservableObject {

    static let shared = AppSettings()

    private enum Key {
        static let focusMinutes = "focusMinutes"
        static let shortBreakMinutes = "shortBreakMinutes"
        static let longBreakMinutes = "longBreakMinutes"
        static let setsBeforeLongBreak = "setsBeforeLongBreak"
        static let autoStartBreak = "autoStartBreak"
        static let autoStartFocus = "autoStartFocus"
        static let showTimeInMenuBar = "showTimeInMenuBar"
        static let notificationsEnabled = "notificationsEnabled"
        static let soundEnabled = "soundEnabled"
        static let soundName = "soundName"
        static let hotKeyEnabled = "hotKeyEnabled"
        static let hotKeyCode = "hotKeyCode"
        static let hotKeyModifiers = "hotKeyModifiers"
    }

    /// 選択できるシステムサウンド（/System/Library/Sounds）
    static let availableSounds = [
        "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero",
        "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink",
    ]

    private let defaults = UserDefaults.standard

    @Published var focusMinutes: Int {
        didSet { defaults.set(focusMinutes, forKey: Key.focusMinutes) }
    }
    @Published var shortBreakMinutes: Int {
        didSet { defaults.set(shortBreakMinutes, forKey: Key.shortBreakMinutes) }
    }
    @Published var longBreakMinutes: Int {
        didSet { defaults.set(longBreakMinutes, forKey: Key.longBreakMinutes) }
    }
    @Published var setsBeforeLongBreak: Int {
        didSet { defaults.set(setsBeforeLongBreak, forKey: Key.setsBeforeLongBreak) }
    }
    @Published var autoStartBreak: Bool {
        didSet { defaults.set(autoStartBreak, forKey: Key.autoStartBreak) }
    }
    @Published var autoStartFocus: Bool {
        didSet { defaults.set(autoStartFocus, forKey: Key.autoStartFocus) }
    }
    @Published var showTimeInMenuBar: Bool {
        didSet { defaults.set(showTimeInMenuBar, forKey: Key.showTimeInMenuBar) }
    }
    @Published var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Key.notificationsEnabled) }
    }
    @Published var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: Key.soundEnabled) }
    }
    @Published var soundName: String {
        didSet { defaults.set(soundName, forKey: Key.soundName) }
    }
    @Published var hotKeyEnabled: Bool {
        didSet { defaults.set(hotKeyEnabled, forKey: Key.hotKeyEnabled) }
    }
    @Published var hotKeyCode: Int {
        didSet { defaults.set(hotKeyCode, forKey: Key.hotKeyCode) }
    }
    /// NSEvent.ModifierFlags.rawValue（デバイス非依存のフラグのみ）
    @Published var hotKeyModifiers: UInt {
        didSet { defaults.set(Int(hotKeyModifiers), forKey: Key.hotKeyModifiers) }
    }

    private init() {
        let controlOption = NSEvent.ModifierFlags([.control, .option]).rawValue

        defaults.register(defaults: [
            Key.focusMinutes: 25,
            Key.shortBreakMinutes: 5,
            Key.longBreakMinutes: 15,
            Key.setsBeforeLongBreak: 4,
            Key.autoStartBreak: true,
            Key.autoStartFocus: false,
            Key.showTimeInMenuBar: true,
            Key.notificationsEnabled: true,
            Key.soundEnabled: true,
            Key.soundName: "Glass",
            Key.hotKeyEnabled: true,
            Key.hotKeyCode: 49,  // Space
            Key.hotKeyModifiers: Int(controlOption),
        ])

        focusMinutes = defaults.integer(forKey: Key.focusMinutes)
        shortBreakMinutes = defaults.integer(forKey: Key.shortBreakMinutes)
        longBreakMinutes = defaults.integer(forKey: Key.longBreakMinutes)
        setsBeforeLongBreak = defaults.integer(forKey: Key.setsBeforeLongBreak)
        autoStartBreak = defaults.bool(forKey: Key.autoStartBreak)
        autoStartFocus = defaults.bool(forKey: Key.autoStartFocus)
        showTimeInMenuBar = defaults.bool(forKey: Key.showTimeInMenuBar)
        notificationsEnabled = defaults.bool(forKey: Key.notificationsEnabled)
        soundEnabled = defaults.bool(forKey: Key.soundEnabled)
        soundName = defaults.string(forKey: Key.soundName) ?? "Glass"
        hotKeyEnabled = defaults.bool(forKey: Key.hotKeyEnabled)
        hotKeyCode = defaults.integer(forKey: Key.hotKeyCode)
        hotKeyModifiers = UInt(max(0, defaults.integer(forKey: Key.hotKeyModifiers)))
    }
}
