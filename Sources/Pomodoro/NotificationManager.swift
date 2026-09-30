import AppKit
import UserNotifications

final class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationManager()

    /// システム側の許可状態。通知が出ない理由を設定画面に出すために保持する。
    /// `.app` バンドル外で起動しているときは nil。
    @Published private(set) var authorizationStatus: UNAuthorizationStatus?

    /// .app バンドルとして起動していないと通知は使えない（サウンドだけ鳴らす）
    private var center: UNUserNotificationCenter? {
        guard Bundle.main.bundleIdentifier != nil else { return nil }
        return UNUserNotificationCenter.current()
    }

    private override init() { super.init() }

    func requestAuthorization() {
        guard let center else {
            NSLog("通知: .app バンドルとして起動していないため通知は使えません")
            return
        }
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
            if let error {
                NSLog("通知: 許可のリクエストに失敗しました: \(error.localizedDescription)")
            }
            if !granted {
                NSLog("通知: 許可されませんでした")
            }
            self?.refreshAuthorizationStatus()
        }
    }

    /// システム設定で許可を変更されている場合があるので、都度取り直す。
    func refreshAuthorizationStatus() {
        guard let center else {
            DispatchQueue.main.async { self.authorizationStatus = nil }
            return
        }
        center.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.authorizationStatus = settings.authorizationStatus
            }
        }
    }

    func announce(
        finished: Phase,
        next: Phase,
        nextMinutes: Int,
        completedSets: Int,
        setsBeforeLongBreak: Int
    ) {
        let settings = AppSettings.shared

        if settings.soundEnabled {
            playSound(named: settings.soundName)
        }

        var body = "次は\(next.title)（\(nextMinutes)分）"
        if finished == .focus {
            body += " · 作業 \(completedSets)/\(setsBeforeLongBreak) セット"
        }
        sendNotification(title: "\(finished.title)が終わりました", body: body)
    }

    /// 設定画面から実際の送信経路をそのまま試すための送信。
    func sendTestNotification() {
        sendNotification(title: "通知のテスト", body: "この通知が見えていれば設定は正しく動いています")
    }

    private func sendNotification(title: String, body: String) {
        guard AppSettings.shared.notificationsEnabled else {
            NSLog("通知: 設定で通知がオフになっているため送信しません")
            return
        }
        guard let center else {
            NSLog("通知: .app バンドルとして起動していないため送信できません")
            return
        }
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else {
            NSLog("通知: 許可されていないため送信できません（状態: \(statusDescription)）")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        // サウンドは NSSound 側で鳴らすので、通知側では鳴らさない
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        center.add(request) { error in
            if let error {
                NSLog("通知: 送信に失敗しました: \(error.localizedDescription)")
            }
        }
    }

    /// ログと設定画面に出す許可状態の説明。
    var statusDescription: String {
        switch authorizationStatus {
        case .authorized, .provisional:
            return "許可されています"
        case .denied:
            return "システム設定で拒否されています"
        case .notDetermined:
            return "まだ許可を求めていません"
        case .ephemeral:
            return "一時的に許可されています"
        case nil:
            return ".app バンドルとして起動していません"
        @unknown default:
            return "不明な状態です"
        }
    }

    /// 通知が出ない状態かどうか（設定画面で案内を出す判定に使う）。
    var needsAttention: Bool {
        authorizationStatus != .authorized && authorizationStatus != .provisional
    }

    func openSystemNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") else { return }
        NSWorkspace.shared.open(url)
    }

    func playSound(named name: String) {
        if let sound = NSSound(named: NSSound.Name(name)) {
            sound.stop()
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    // アプリが手前にいるときも通知を表示する
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner])
    }
}
