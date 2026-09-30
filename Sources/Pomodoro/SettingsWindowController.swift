import AppKit
import SwiftUI

final class SettingsWindowController {

    static let shared = SettingsWindowController()

    private var window: NSWindow?

    private init() {}

    func show() {
        if window == nil {
            let hostingView = NSHostingView(rootView: SettingsView())
            var size = hostingView.fittingSize
            // レイアウトが確定していないときの保険
            if size.width < 200 { size.width = 460 }
            if size.height < 200 { size.height = 640 }
            hostingView.frame = NSRect(origin: .zero, size: size)

            let window = NSWindow(
                contentRect: hostingView.frame,
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "ポモドーロタイマーの設定"
            window.contentView = hostingView
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
