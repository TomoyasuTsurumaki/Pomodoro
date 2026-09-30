import AppKit
import Combine
import Foundation

enum Phase: String {
    case focus
    case shortBreak
    case longBreak

    var title: String {
        switch self {
        case .focus: return "作業"
        case .shortBreak: return "休憩"
        case .longBreak: return "長い休憩"
        }
    }

    var menuBarIcon: MenuBarIconKind {
        switch self {
        case .focus: return .tomato
        // トマトがベタ塗りなので、SF Symbols 側も .fill で重さを揃える
        case .shortBreak: return .symbol("cup.and.saucer.fill")
        case .longBreak: return .symbol("moon.zzz.fill")
        }
    }
}

/// メニューバーに出すアイコンの種類（実際の描画は MenuBarController 側）
enum MenuBarIconKind {
    /// 自前で描くトマト（TomatoIcon）
    case tomato
    /// SF Symbols
    case symbol(String)
}

/// 残り時間は「終了時刻」から毎回計算するので、スリープや小さなずれで狂わない。
final class PomodoroEngine: ObservableObject {

    static let shared = PomodoroEngine()

    @Published private(set) var phase: Phase = .focus
    @Published private(set) var isRunning = false
    @Published private(set) var remaining: Int = 0
    /// 現在の長い休憩サイクル内で完了した作業セット数
    @Published private(set) var completedSets: Int = 0
    /// 起動してから完了した作業セットの総数
    @Published private(set) var totalFocusSets: Int = 0

    private let settings = AppSettings.shared
    private var timer: Timer?
    private var deadline: Date?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        remaining = duration(for: .focus)

        // 停止中に設定を変えたら、そのフェーズの長さに追従させる
        let durationChanged = Publishers.MergeMany(
            settings.$focusMinutes.map { _ in () },
            settings.$shortBreakMinutes.map { _ in () },
            settings.$longBreakMinutes.map { _ in () }
        )
        durationChanged
            .dropFirst(3)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.syncDurationIfIdle() }
            .store(in: &cancellables)

        // スリープ復帰直後に残り時間を再計算する
        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.tick() }
            .store(in: &cancellables)
    }

    // MARK: - 表示用

    var totalForCurrentPhase: Int { duration(for: phase) }

    var progress: Double {
        let total = totalForCurrentPhase
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(total - remaining) / Double(total)))
    }

    var displayTime: String {
        let seconds = max(0, remaining)
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    /// 手つかずの状態（開始前でフルの残り時間）かどうか
    var isFresh: Bool { !isRunning && remaining == totalForCurrentPhase }

    var menuBarIcon: MenuBarIconKind {
        isFresh || isRunning ? phase.menuBarIcon : .symbol("pause.circle.fill")
    }

    // MARK: - 操作

    func start() {
        guard !isRunning else { return }
        if remaining <= 0 { remaining = duration(for: phase) }
        deadline = Date().addingTimeInterval(TimeInterval(remaining))
        isRunning = true
        startTicker()
    }

    func pause() {
        guard isRunning else { return }
        if let deadline {
            remaining = max(0, Int(ceil(deadline.timeIntervalSinceNow)))
        }
        stopTicker()
        deadline = nil
        isRunning = false
    }

    func toggle() {
        isRunning ? pause() : start()
    }

    /// 現在のフェーズを最初から
    func reset() {
        stopTicker()
        deadline = nil
        isRunning = false
        remaining = duration(for: phase)
    }

    /// 作業フェーズに戻してセット数もゼロに
    func resetAll() {
        stopTicker()
        deadline = nil
        isRunning = false
        phase = .focus
        completedSets = 0
        remaining = duration(for: .focus)
    }

    /// 完了扱いにせず次のフェーズへ
    func skip() {
        stopTicker()
        isRunning = false
        let next: Phase
        if phase == .focus {
            let interval = max(1, settings.setsBeforeLongBreak)
            next = (completedSets + 1) % interval == 0 ? .longBreak : .shortBreak
        } else {
            next = .focus
        }
        move(to: next)
    }

    // MARK: - 内部

    private func duration(for phase: Phase) -> Int {
        let minutes: Int
        switch phase {
        case .focus: minutes = settings.focusMinutes
        case .shortBreak: minutes = settings.shortBreakMinutes
        case .longBreak: minutes = settings.longBreakMinutes
        }
        return max(1, min(minutes, 180)) * 60
    }

    private func syncDurationIfIdle() {
        guard !isRunning else { return }
        remaining = duration(for: phase)
    }

    private func startTicker() {
        stopTicker()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer.tolerance = 0.1
        // .common にしておくとメニューを開いている間も進む
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Timer を止めるだけ。deadline のクリアは呼び出し側の責務
    private func stopTicker() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard isRunning, let deadline else { return }
        let left = Int(ceil(deadline.timeIntervalSinceNow))
        if left <= 0 {
            remaining = 0
            complete()
        } else if left != remaining {
            remaining = left
        }
    }

    private func complete() {
        stopTicker()
        isRunning = false

        let finished = phase
        let interval = max(1, settings.setsBeforeLongBreak)

        if finished == .focus {
            completedSets += 1
            totalFocusSets += 1
        }

        let next: Phase
        if finished == .focus {
            next = completedSets % interval == 0 ? .longBreak : .shortBreak
        } else {
            next = .focus
        }

        // 長い休憩を取り終えたらサイクルをリセット
        if finished == .longBreak { completedSets = 0 }

        NotificationManager.shared.announce(
            finished: finished,
            next: next,
            nextMinutes: duration(for: next) / 60,
            completedSets: completedSets,
            setsBeforeLongBreak: interval
        )

        move(to: next)

        let shouldAutoStart = next == .focus ? settings.autoStartFocus : settings.autoStartBreak
        if shouldAutoStart { start() }
    }

    private func move(to next: Phase) {
        deadline = nil
        phase = next
        remaining = duration(for: next)
    }
}
