# ポモドーロタイマー（macOS メニューバーアプリ）

Swift / SwiftUI + AppKit で書いたメニューバー常駐のポモドーロタイマーです。Dock にはアイコンが出ません（`LSUIElement`）。

## 機能

- メニューバー常駐。**アイコンのみ / アイコン + 残り時間** を切り替え可能（どちらでもクリックで残り時間を表示）
- クリックで開く小さなパネルに、フェーズ名・残り時間・進捗バー・セット進捗（●●○○）を表示
- 開始 / 一時停止 / 次のフェーズへ / このフェーズをやり直す / セット数をリセット
- 作業・休憩・長い休憩の時間を設定可能（既定は 25 / 5 / 15 分）
- **4 セットごとに長い休憩を自動挿入**（間隔は 1〜12 セットで変更可能）
- フェーズ終了時に**通知 + サウンド**（システムサウンド 14 種、試聴ボタン付き）
- **グローバルショートカットで開始 / 一時停止**（既定 `⌃⌥Space`、設定画面で好きなキーに変更可能）
- 自動で次のフェーズを開始するかどうかを、休憩と作業でそれぞれ切り替え
- 残り時間は「終了時刻」から都度計算するので、スリープしてもずれません
- 設定は `UserDefaults` に自動保存

## 動作環境

macOS 13 (Ventura) 以降 / Xcode 15 以降（または Swift 5.9 以降のコマンドラインツール）

## ビルドと起動

```bash
cd Pomodoro
chmod +x build_app.sh
./build_app.sh
open build/Pomodoro.app
```

初回起動時に通知の許可を尋ねられます。常用するなら `/Applications` にコピーしてください。

```bash
cp -R build/Pomodoro.app /Applications/
```

### アイコンを作り直す

アイコンは画像素材ではなく `TomatoIcon.swift` の描画コードです。メニューバーのトマトは実行時に描いているので何もしなくて構いませんが、アプリアイコン（`Resources/AppIcon.icns`）は生成物なので、デザインを変えたら作り直してコミットしてください。

```bash
swiftc Tools/MakeAppIcon.swift Sources/Pomodoro/TomatoIcon.swift -o "$TMPDIR/makeicon" && "$TMPDIR/makeicon"
```

### Xcode で開いて編集する場合

`Package.swift` を Xcode で開けば、そのままエディタで編集・ビルドできます。ただし Xcode の Run では `.app` バンドルを経由しないため通知が出ません。通知を含めて確認するときは `./build_app.sh` を使ってください。

### ログイン時に自動起動させる

システム設定 → 一般 → ログイン項目 で `Pomodoro.app` を追加してください。

## 使い方

| 操作 | 方法 |
| --- | --- |
| 開始 / 一時停止 | メニューの「開始」、または `⌃⌥Space` |
| 残り時間の確認 | メニューバーのアイコンをクリック |
| 表示の切り替え | メニューの「残り時間をメニューバーに表示」 |
| 設定 | メニューの「設定…」 |

## ファイル構成

| ファイル | 役割 |
| --- | --- |
| `main.swift` | エントリポイント |
| `AppDelegate.swift` | 起動処理、ホットキーの登録 |
| `PomodoroEngine.swift` | タイマーとフェーズ遷移のロジック |
| `AppSettings.swift` | 設定の保持と永続化 |
| `MenuBarController.swift` | メニューバー項目とメニュー、上部パネル |
| `SettingsView.swift` | 設定画面とショートカット入力欄 |
| `SettingsWindowController.swift` | 設定ウィンドウの管理 |
| `NotificationManager.swift` | 通知とサウンド |
| `HotKeyManager.swift` | Carbon によるグローバルショートカット |
| `TomatoIcon.swift` | トマトアイコンの描画（メニューバー / アプリアイコン共通） |

## 補足

- グローバルショートカットは Carbon の `RegisterEventHotKey` を使っているため、アクセシビリティ権限は不要です。他のアプリが同じ組み合わせを先に登録している場合は登録に失敗し、コンソールに警告が出ます。
- 修飾キーなしのショートカットは他のアプリの入力を奪うため、登録できないようにしています。
- コントロールセンターへのコントロール追加は、macOS では公式にサポートされていません（`ControlWidget` は iOS / iPadOS / watchOS 向け）。今回はメニューバー + グローバルショートカットで代替しています。
