# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

macOS メニューバー常駐のポモドーロタイマー。Swift Package Manager の単一 executable target（`Sources/Pomodoro`）で、AppKit を土台に SwiftUI ビューを `NSHostingView` で埋め込む構成。Xcode プロジェクトファイルはなく、`Package.swift` を Xcode で直接開く。

## コマンド

```bash
swift build                 # デバッグビルド（構文確認はこれが最速）
./build_app.sh              # release ビルド → build/Pomodoro.app を生成しアドホック署名
open build/Pomodoro.app     # 起動
UNIVERSAL=1 VERSION=1.2.0 ./build_app.sh   # 配布用（arm64 + x86_64、バージョン指定）
```

リリースは `v*` タグを push すると `.github/workflows/release.yml` が上記の配布用ビルドを行い、`ditto` で zip にして GitHub Releases に添付する（バージョンはタグ名から `v` を除いたもの）。

テストターゲットは存在しない。Lint 設定（SwiftLint 等）もない。

**通知の検証は必ず `./build_app.sh` 経由で行うこと。** `swift run` や Xcode の Run では `.app` バンドルを通らず `Bundle.main.bundleIdentifier` が nil になるため、`NotificationManager` が通知を丸ごとスキップしてサウンドだけになる（`NotificationManager.swift` の `center` プロパティ）。

`build_app.sh` は Info.plist をヒアドキュメントで生成する。バンドル設定（`LSUIElement`、バージョン、bundle ID）を変えるならこのスクリプトを編集する — plist ファイルは別置きされていない。同様にアプリアイコンもこのスクリプトが `Resources/AppIcon.icns` を `Contents/Resources/` へコピーしている。

## アーキテクチャ

### シングルトン + Combine の一方向データフロー

3 つのシングルトンが状態を持つ：

- `PomodoroEngine.shared` — タイマーとフェーズ遷移（`ObservableObject`）
- `AppSettings.shared` — 全設定（`ObservableObject`、`UserDefaults` に自動保存）
- `HotKeyManager.shared` — Carbon のグローバルホットキー（状態は非 Observable）

`MenuBarController` は engine と settings の `objectWillChange` を購読してメニューバー表示を再構築し、`AppDelegate` は settings の変更を購読してホットキーを再登録する。SwiftUI 側（`MenuHeaderView`、`SettingsView`）は同じシングルトンを `@ObservedObject` で受け取る。新しい UI を足すときはこのパターンに従う。

### タイマーは「残り秒数のカウントダウン」ではない

`PomodoroEngine` は `deadline: Date` を持ち、残り時間は毎ティック `deadline.timeIntervalSinceNow` から計算し直す。0.25 秒間隔の `Timer` は `RunLoop.main` の `.common` モードに追加してある（メニューを開いている間も止まらないため）。加えて `NSWorkspace.didWakeNotification` で `tick()` を呼び、スリープ復帰時にずれを解消する。この設計を壊すような「remaining を毎秒 1 減らす」実装に変えないこと。

### フェーズ遷移

`focus → shortBreak | longBreak → focus` のループ。`completedSets` は長い休憩サイクル内のカウンタで長い休憩の完了時に 0 に戻り、`totalFocusSets` は起動以降の累計（永続化しない）。`complete()`（自然終了、通知あり、autoStart 判定あり）と `skip()`（手動、通知なし、セット数を増やさない）は別経路なので、遷移ロジックを変えるときは両方を見る。

### アイコン

画像素材は持たず、`TomatoIcon.swift` が Core Graphics で描く。メニューバー用（`menuBarImage`、テンプレート画像）とアプリアイコン用（`appIconImage`、フルカラー）が同じ形状生成関数（`bodyPath` / `calyxPath` / `stemPath`）を共有する。アプリアイコンだけは事前生成物で、`Tools/MakeAppIcon.swift`（`TomatoIcon.swift` と一緒に `swiftc` でコンパイルして実行）が `Resources/AppIcon.icns` を書き出す。描画を変えたらこのスクリプトを実行し直すこと。

メニューバーのアイコン種別は `MenuBarIconKind`（`.tomato` / `.symbol(String)`）で表し、実際の画像化は `MenuBarController.refreshStatusButton()` が行う。作業フェーズだけトマト、休憩系はフェーズを区別するため SF Symbols のまま。

### 設定の永続化

`AppSettings` は `defaults.register(defaults:)` で既定値を登録し、各 `@Published` の `didSet` で書き戻す。設定項目を追加するには `Key` enum・`@Published` プロパティ・`register` の既定値・`init` の読み出しの 4 箇所を揃えて編集する。

### グローバルショートカット

Carbon の `RegisterEventHotKey`（アクセシビリティ権限が不要なため意図的に採用）。修飾キーなしの組み合わせは `HotKeyManager.apply` で拒否している。他アプリと衝突すると登録が失敗し `NSLog` に警告が出るだけで、UI 上はエラーにならない。キーコード → 表示名の対応表は `KeyCombo.names`。

## 慣習

- コード内のコメント・UI 文言・通知文はすべて日本語。
- 内部識別子（`Phase.focus` 等）は英語、ユーザーに見える文字列は `Phase.title` のような computed property に分離する。
- ファイル 1 つにつき 1 つの責務（README のファイル構成表を参照）。
