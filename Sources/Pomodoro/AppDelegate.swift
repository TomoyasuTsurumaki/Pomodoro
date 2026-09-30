import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var menuBarController: MenuBarController?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationManager.shared.requestAuthorization()

        menuBarController = MenuBarController()

        HotKeyManager.shared.onPress = {
            PomodoroEngine.shared.toggle()
        }
        applyHotKey()

        AppSettings.shared.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.applyHotKey() }
            .store(in: &cancellables)

        // システム設定で通知の許可を変えられている場合があるので、戻ってきたら取り直す
        NotificationCenter.default
            .publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { _ in NotificationManager.shared.refreshAuthorizationStatus() }
            .store(in: &cancellables)
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotKeyManager.shared.unregister()
    }

    private func applyHotKey() {
        let settings = AppSettings.shared
        HotKeyManager.shared.apply(
            enabled: settings.hotKeyEnabled,
            keyCode: settings.hotKeyCode,
            modifiers: settings.hotKeyModifiers
        )
    }
}
