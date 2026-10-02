---
name: build-and-push
description: 配布用ビルド（リリース CI と同じ UNIVERSAL=1 ./build_app.sh）が通ることを確認してから、変更をコミットして push する。
argument-hint: "[コミットメッセージ]"
disable-model-invocation: true
---

# ビルドしてからコミット・push する

ビルドが通らない状態で push しないためのスキル。途中の手順が 1 つでも失敗したら、そこで止めてエラーを報告する。コミットも push もしないこと。

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

- SwiftPM は自前の `sandbox-exec` を使う。Claude のサンドボックスの中では入れ子にできず `sandbox_apply: Operation not permitted` で失敗するので、このコマンドは最初からサンドボックスの外で実行する。
- ビルドに失敗したら、コンパイルエラーの該当箇所（`ファイル:行`）を示して止める。勝手に修正してから先へ進まないこと。

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

## 6. 報告

次の 4 点を短く報告する。

- ビルド結果（アーキテクチャ、署名）
- コミットのハッシュとメッセージ
- push 先のブランチ
- リリースするには、`main` 向けの PR に `release:major` / `release:minor` / `release:patch` のいずれかのラベルを付けてマージすればよいこと。タグを手で打つ必要はない。
