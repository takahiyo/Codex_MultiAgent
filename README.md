# Codex MultiAgent

Codexの動的マルチエージェント運用をWindows PC間で安全に共有するための設定リポジトリです。

## 新しいPCへの導入（PowerShell）

前提: GitとCodexがインストール済みであること。スクリプトは実行前に内容を確認してください。

```powershell
git clone https://github.com/takahiyo/Codex_MultiAgent.git
cd Codex_MultiAgent
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify.ps1
```

既存の `~/.codex/AGENTS.md` が異なる場合は上書きせず終了コード2で停止します。確認して共通版へ置き換える場合のみ以下を実行します（置き換え前に自動バックアップ）。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Force
```

プレビューには `-WhatIf` を利用できます。 `CODEX_HOME` 環境変数が設定されている場合はその場所を使用します。

## ほかのPCで更新

```powershell
git pull --ff-only
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify.ps1
```

更新時に既存AGENTS.mdと内容が異なる場合は止まります。差分を調べてから、既存の独自ルールを保持したいときは手動で統合してください。一括置換してよければ `-Force` を指定します。

## 管理範囲

| ファイル | 取り扱い |
|---|---|
| `policy/AGENTS.md` | 共通の動的委任方針。全PCへ配布 |
| `scripts/install.ps1` | 既存ファイル保護・バックアップ・配置 |
| `scripts/verify.ps1` | ハッシュで配置を検証 |
| `~/.codex/config.toml` | PC固有。インストーラーは**一切変更しない** |
| `~/.codex/auth.json`、鍵、セッション履歴 | **同期・コミットしない** |
| プロジェクト内`AGENTS.md` | 各プロジェクトで管理 |

`~/.codex/config.toml` でサブエージェントの有効化や上限の設定が必要な環境では、端末側のCodexバージョンと設定仕様を確認して個別に設定してください。

## インストール後の検証

新しいCodexセッションを開き、次を依頼してください。

> ファイルは変更せず、現在の作業構造を調査してください。簡単なタスクを委任しない判断と、読み取り専用の調査をサブエージェントへ委任する判断を比較してください。委任できる場合は、利用可能なモデル・推論強度を明示指定して1件実行し、指定値と実際に確認できた適用値を区別して報告してください。Gitへの書き込みは行わないでください。

## 注意事項

- エージェントのモデル・推論強度は、作業難易度と利用可能な選択肢を見て判断します。固定の役割割り当てではありません。
- `spawn_agent` に指定できても、バックエンドが実際に採用した値を確認できるとは限りません。指定受理と実適用確認は別物です。
- このリポジトリはポリシーを配布するものであり、モデル最適性や全Codexバージョンとの互換性は保証しません。
- `-ExecutionPolicy Bypass` は起動するPowerShellプロセスの指定です。組織の強制ポリシーを回避できるとは限りません。
- GitのCommit、Push、破壊的操作はユーザーの明示的な許可がある場合のみ実施する方針です。
