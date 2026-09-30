import AppKit
import Combine
import SwiftUI

final class MenuBarController: NSObject, NSMenuDelegate {

    private let statusItem: NSStatusItem
    private let engine = PomodoroEngine.shared
    private let settings = AppSettings.shared
    private var cancellables = Set<AnyCancellable>()

    private let menu = NSMenu()
    private let headerItem = NSMenuItem()
    private let startPauseItem = NSMenuItem()
    private let skipItem = NSMenuItem()
    private let resetItem = NSMenuItem()
    private let resetAllItem = NSMenuItem()
    private let showTimeItem = NSMenuItem()

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        buildMenu()
        statusItem.menu = menu
        refreshStatusButton()

        // タイマーや設定が変わったら見た目を更新
        engine.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshStatusButton()
                self?.refreshMenuItems()
            }
            .store(in: &cancellables)

        settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshStatusButton()
                self?.refreshMenuItems()
            }
            .store(in: &cancellables)
    }

    // MARK: - メニューバーのボタン

    private func refreshStatusButton() {
        guard let button = statusItem.button else { return }

        let image: NSImage?
        switch engine.menuBarIcon {
        case .tomato:
            image = TomatoIcon.menuBarImage()
        case .symbol(let name):
            image = NSImage(
                systemSymbolName: name,
                accessibilityDescription: "ポモドーロタイマー"
            )
        }
        image?.isTemplate = true
        button.image = image

        if settings.showTimeInMenuBar {
            button.font = NSFont.monospacedDigitSystemFont(
                ofSize: NSFont.systemFontSize(for: .small) + 1,
                weight: .regular
            )
            button.title = " \(engine.displayTime)"
            button.imagePosition = .imageLeading
        } else {
            button.title = ""
            button.imagePosition = .imageOnly
        }

        button.toolTip = "\(engine.phase.title) · 残り \(engine.displayTime)"
    }

    // MARK: - メニュー

    private func buildMenu() {
        menu.delegate = self
        menu.autoenablesItems = false

        let header = NSHostingView(rootView: MenuHeaderView(engine: engine, settings: settings))
        // 高さを固定すると最下段（累計セット数）が見切れるので、SwiftUI 側の要求サイズに合わせる
        let headerWidth: CGFloat = 252
        header.frame = NSRect(x: 0, y: 0, width: headerWidth, height: 120)
        header.frame.size.height = max(header.fittingSize.height, 120)
        headerItem.view = header
        menu.addItem(headerItem)

        menu.addItem(.separator())

        startPauseItem.title = "開始"
        startPauseItem.target = self
        startPauseItem.action = #selector(toggleTimer)
        menu.addItem(startPauseItem)

        skipItem.title = "次のフェーズへ"
        skipItem.target = self
        skipItem.action = #selector(skipPhase)
        menu.addItem(skipItem)

        resetItem.title = "このフェーズをやり直す"
        resetItem.target = self
        resetItem.action = #selector(resetPhase)
        menu.addItem(resetItem)

        resetAllItem.title = "セット数をリセット"
        resetAllItem.target = self
        resetAllItem.action = #selector(resetEverything)
        menu.addItem(resetAllItem)

        menu.addItem(.separator())

        showTimeItem.title = "残り時間をメニューバーに表示"
        showTimeItem.target = self
        showTimeItem.action = #selector(toggleShowTime)
        menu.addItem(showTimeItem)

        let settingsItem = NSMenuItem(
            title: "設定…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "ポモドーロタイマーを終了",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        refreshMenuItems()
    }

    private func refreshMenuItems() {
        startPauseItem.title = engine.isRunning ? "一時停止" : (engine.isFresh ? "開始" : "再開")
        resetItem.isEnabled = !engine.isFresh
        showTimeItem.state = settings.showTimeInMenuBar ? .on : .off

        if settings.hotKeyEnabled {
            let combo = KeyCombo.description(
                keyCode: settings.hotKeyCode,
                modifiers: settings.hotKeyModifiers
            )
            startPauseItem.toolTip = "ショートカット: \(combo)"
        } else {
            startPauseItem.toolTip = nil
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshMenuItems()
    }

    // MARK: - アクション

    @objc private func toggleTimer() {
        engine.toggle()
    }

    @objc private func skipPhase() {
        engine.skip()
    }

    @objc private func resetPhase() {
        engine.reset()
    }

    @objc private func resetEverything() {
        engine.resetAll()
    }

    @objc private func toggleShowTime() {
        settings.showTimeInMenuBar.toggle()
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.show()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - メニュー上部の表示

private struct MenuHeaderView: View {

    @ObservedObject var engine: PomodoroEngine
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(engine.phase.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if !engine.isRunning && !engine.isFresh {
                    Text("一時停止中")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Text(engine.displayTime)
                .font(.system(size: 34, weight: .light, design: .rounded))
                .monospacedDigit()

            ProgressView(value: engine.progress)
                .progressViewStyle(.linear)
                .tint(engine.phase == .focus ? .accentColor : .secondary)

            HStack(spacing: 5) {
                let total = max(1, settings.setsBeforeLongBreak)
                ForEach(Array(0..<total), id: \.self) { index in
                    Circle()
                        .fill(index < engine.completedSets ? Color.accentColor : Color.secondary.opacity(0.25))
                        .frame(width: 6, height: 6)
                }
                Spacer()
                Text("累計 \(engine.totalFocusSets) セット")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}
