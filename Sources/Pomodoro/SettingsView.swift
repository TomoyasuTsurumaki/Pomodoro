import AppKit
import SwiftUI

struct SettingsView: View {

    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var notifications = NotificationManager.shared

    var body: some View {
        Form {
            Section("時間") {
                Stepper(value: $settings.focusMinutes, in: 1...180) {
                    LabeledContent("作業", value: "\(settings.focusMinutes) 分")
                }
                Stepper(value: $settings.shortBreakMinutes, in: 1...180) {
                    LabeledContent("休憩", value: "\(settings.shortBreakMinutes) 分")
                }
                Stepper(value: $settings.longBreakMinutes, in: 1...180) {
                    LabeledContent("長い休憩", value: "\(settings.longBreakMinutes) 分")
                }
                Stepper(value: $settings.setsBeforeLongBreak, in: 1...12) {
                    LabeledContent("長い休憩を挟む間隔", value: "\(settings.setsBeforeLongBreak) セットごと")
                }
            }

            Section("自動で次に進む") {
                Toggle("作業のあと休憩を自動で開始", isOn: $settings.autoStartBreak)
                Toggle("休憩のあと作業を自動で開始", isOn: $settings.autoStartFocus)
            }

            Section("終了時の知らせ") {
                Toggle("通知を表示", isOn: $settings.notificationsEnabled)
                HStack {
                    Text(notifications.statusDescription)
                        .font(.callout)
                        .foregroundStyle(notifications.needsAttention ? .red : .secondary)
                    Spacer()
                    if notifications.needsAttention {
                        Button("システム設定を開く") {
                            notifications.openSystemNotificationSettings()
                        }
                    } else {
                        Button("通知をテスト") {
                            notifications.sendTestNotification()
                        }
                    }
                }
                .disabled(!settings.notificationsEnabled)

                Toggle("サウンドを鳴らす", isOn: $settings.soundEnabled)
                HStack {
                    Picker("サウンド", selection: $settings.soundName) {
                        ForEach(AppSettings.availableSounds, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    Button("再生") {
                        NotificationManager.shared.playSound(named: settings.soundName)
                    }
                }
                .disabled(!settings.soundEnabled)
            }

            Section("メニューバー") {
                Toggle("残り時間を表示", isOn: $settings.showTimeInMenuBar)
                Text(settings.showTimeInMenuBar
                     ? "アイコンの右に残り時間が並びます"
                     : "アイコンだけを表示します。クリックすれば残り時間が出ます")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("ショートカット") {
                Toggle("グローバルショートカットを使う", isOn: $settings.hotKeyEnabled)
                LabeledContent("開始 / 一時停止") {
                    ShortcutRecorder()
                }
                .disabled(!settings.hotKeyEnabled)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { notifications.refreshAuthorizationStatus() }
    }
}

/// クリックしてから押したキーの組み合わせを取り込むボタン。
private struct ShortcutRecorder: View {

    @ObservedObject private var settings = AppSettings.shared
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 8) {
            Button(action: toggleRecording) {
                Text(label)
                    .font(.system(size: 12, design: .rounded))
                    .frame(minWidth: 96)
            }
            if isRecording {
                Text("Esc で取り消し")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .onDisappear(perform: stopRecording)
    }

    private var label: String {
        if isRecording { return "キーを押す…" }
        return KeyCombo.description(
            keyCode: settings.hotKeyCode,
            modifiers: settings.hotKeyModifiers
        )
    }

    private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            if event.keyCode == 53 {  // Esc
                stopRecording()
                return nil
            }
            let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard !flags.isEmpty else {
                // 修飾キーなしでは他のアプリの入力を奪ってしまう
                NSSound.beep()
                return nil
            }
            settings.hotKeyCode = Int(event.keyCode)
            settings.hotKeyModifiers = flags.rawValue
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        isRecording = false
    }
}
