---
name: build-and-push
description: 配布用ビルド（リリース CI と同じ UNIVERSAL=1 ./build_app.sh）が通ることを確認してから、変更をコミット・push し、main 向けの PR を作成または更新してリリース用ラベルを付ける。
argument-hint: "[コミットメッセージ]"
disable-model-invocation: true
---

# ビルドしてからコミット・push・PR まで行う

ビルドが通らない状態で push しないためのスキル。途中の手順が 1 つでも失敗したら、そこで止めてエラーを報告する。それより先の手順（コミット・push・PR）には進まないこと。

## サンドボックスの外で実行するコマンド

次のコマンドは Claude のサンドボックスの中では動かないので、最初から `dangerouslyDisableSandbox: true` で実行する。実行のたびにユーザーの許可確認が出るので、それとは別に文章で確認する必要はない。

| コマンド | サンドボックス内で失敗する理由 |
| --- | --- |
| `./build_app.sh`（`swift build`） | SwiftPM が自前の `sandbox-exec` を使うため、入れ子にできない |
| `git push` | リモートは SSH（`git@github.com`）で、`~/.ssh` が読めない |
| `gh`（PR・ラベル） | `api.github.com` への接続が拒否されている |
| `.github/` 配下への書き込み | Write / Edit ツールの権限設定で拒否されている。Bash のヒアドキュメントで書く |

これ以外の読み取りや書き込み（`git status`、`git diff`、`git add`、`git commit` など）は、サンドボックスの中で実行する。

## 1. 変更を確認する

```bash
git status --short
git diff HEAD --stat
git log --oneline @{u}..HEAD 2>/dev/null   # 未 push のコミット
```

コミットする変更も未 push のコミットもなければ「何もすることがない」と報告して終わる。

## 2. 配布用ビルド

リリース CI（`.github/workflows/release.yml`）と同じ条件でビルドする。ユニバーサルビルドにするのは、x86_64 のときだけ出るコンパイルエラーを push 前に見つけるため。

```bash
UNIVERSAL=1 ./build_app.sh
```

ビルドに失敗したら、コンパイルエラーの該当箇所（`ファイル:行`）を示して止める。勝手に修正してから先へ進まないこと。

## 3. 成果物を確認する

```bash
lipo -archs build/Pomodoro.app/Contents/MacOS/Pomodoro          # → x86_64 arm64
codesign --verify --deep --strict build/Pomodoro.app && echo OK
```

`build/` は `.gitignore` 済みなので、コミットには含まれない。

## 4. コミット

- 手順 1 で見た変更だけを、ファイル名を指定して `git add` する（`git add -A` は使わない）。`.claude/settings.local.json` のような個人設定が紛れ込んでいたら除外する。
- 引数があればそれをコミットメッセージにする。なければ差分から日本語で 1 行の要約を作り、必要なら本文を足す。
- コミットする変更がなく、未 push のコミットだけがあるときは、この手順を飛ばす。

## 5. push

- 現在のブランチが `main` なら push せずに止めて、ユーザーに確認する。
- それ以外は `git push -u origin HEAD` を実行する。

## 6. リリース用ラベルを決める

`main` にマージしたときのリリースは PR のラベルで決まる（`release.yml` が既存の `vX.Y.Z` タグから次のバージョンを採番する）。PR 全体の差分（`git diff origin/main...HEAD --stat` と `git log --oneline origin/main..HEAD`）を見て、ラベルを 1 つ推奨する。

| ラベル | 選ぶ基準 |
| --- | --- |
| `release:major` | 設定の互換性がなくなる、動作環境（`LSMinimumSystemVersion`）を上げるなど、利用者に影響する破壊的変更 |
| `release:minor` | 機能追加、UI や設定項目の追加 |
| `release:patch` | 不具合修正、見た目の微修正 |
| なし | アプリに影響しない変更（README・CLAUDE.md・CI・スキルだけ）、またはすでにリリース済みの中身 |

推奨したラベルを先頭（Recommended）にして AskUserQuestion で確認する。ラベルを付けるとマージ時に実際にリリースされるので、確認なしに付けないこと。

## 7. PR を作成または更新する

まず、このブランチの PR がすでにあるかを確認する。

```bash
gh pr view --json number,url,labels,body
```

- **PR がない場合**: `gh pr create --base main --title "<タイトル>" --body-file - --label <ラベル>` で作る（ラベルなしなら `--label` を付けない）。
- **PR がある場合**: 本文を PR 全体の内容で書き直して `gh pr edit <番号> --body-file -` で更新する。ラベルが手順 6 の結論と違えば `--add-label` / `--remove-label` で揃える。最新のコミットだけを書くのではなく、PR 全体の説明にすること。

本文は日本語で、次の構成にする。

```markdown
## 概要
（何のための変更か 1〜2 文）

## 変更内容
- `ファイル`: 変更点

## 確認済み
- 手順 2・3 のビルド結果（アーキテクチャ、署名）など、実際に確認したことだけ

## 未確認
- 確認できていないこと（なければ節ごと省く）

## リリース
（付けたラベルと、マージ時に作られる見込みのバージョン。ラベルなしなら「リリースしない」）

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

見込みバージョンは、`git tag --list 'v*' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n1` で取った最新タグにラベルを当てはめて計算する。

## 8. 報告

次の点を短く報告する。

- ビルド結果（アーキテクチャ、署名）
- コミットのハッシュとメッセージ
- push 先のブランチ
- PR の URL と、作成したか更新したか
- 付けたラベルと、マージ時に作られる見込みのバージョン（ラベルなしならリリースされないこと）
