# Codex MultiAgent

Codexの動的マルチエージェント運用方針をWindows PC間で共有します。変更対象は配布先の`AGENTS.md`のみです。`config.toml`、認証情報、鍵、履歴は読み取らず、コピー・同期・変更しません。

## 前提と保存場所

- GitとCodexが導入済みのWindows。Windows PowerShell 5.1 / PowerShell 7から実行できます。
- 以下は**PowerShell用**です。各ブロックはどのカレントディレクトリからでも実行できます。プロンプトの`PS C:\...>`は貼り付けません。
- リポジトリは`$HOME\Codex_MultiAgent`に保存します。別の場所なら各ブロックの`$repo`を変更してください。
- 配布先は通常`$HOME\.codex\AGENTS.md`です。`CODEX_HOME`指定時はその直下です。相対パスやリンク先への配布は誤配置防止のため停止します。環境変数の設定は自動変更しません。
- スクリプトを実行前に確認してください。管理者権限は通常不要です。

## 1. 初回取得・導入

既存フォルダーがある場合は上書きせず停止します。既に取得済みなら次の更新手順を使用してください。

```powershell
$ErrorActionPreference = 'Stop'
$repo = Join-Path $HOME 'Codex_MultiAgent'
Set-Location -LiteralPath $HOME
if (Test-Path -LiteralPath $repo) { throw "既存フォルダーがあります。更新手順を使用してください: $repo" }
git clone https://github.com/takahiyo/Codex_MultiAgent.git "$repo"
if ($LASTEXITCODE -ne 0) { throw '取得失敗。導入は実行しません。' }
Set-Location -LiteralPath $repo
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$repo\scripts\install.ps1"
if ($LASTEXITCODE -eq 2) { throw '既存AGENTS.mdとの差分を確認してください（後述）。' }
if ($LASTEXITCODE -ne 0) { throw '導入失敗。' }
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$repo\scripts\verify.ps1"
if ($LASTEXITCODE -ne 0) { throw '配置検証失敗。' }
```

## 2. 取得済みPCの更新

作業ツリーに変更（未追跡ファイルを含む）があるときは停止します。自動stash・resetはしません。リモートURLとブランチを確認し、`main`を早送り更新します。取得失敗時は古い配布元をインストールしません。

```powershell
$ErrorActionPreference = 'Stop'
$repo = Join-Path $HOME 'Codex_MultiAgent'
Set-Location -LiteralPath $repo
$root = git rev-parse --show-toplevel
if ($LASTEXITCODE -ne 0) { throw 'Gitリポジトリではありません。' }
if ([IO.Path]::GetFullPath($root) -ne [IO.Path]::GetFullPath($repo)) { throw 'リポジトリの位置が違います。' }
$origin = git remote get-url origin
if ($LASTEXITCODE -ne 0 -or $origin -notin @('https://github.com/takahiyo/Codex_MultiAgent.git', 'https://github.com/takahiyo/Codex_MultiAgent', 'git@github.com:takahiyo/Codex_MultiAgent.git')) { throw 'originが想定と違います。' }
$branch = git branch --show-current
if ($LASTEXITCODE -ne 0 -or $branch -ne 'main') { throw 'mainブランチで実行してください。' }
$changes = git status --porcelain
if ($LASTEXITCODE -ne 0 -or $changes) { throw 'ローカル変更を確認してから更新してください。' }
git pull --ff-only origin main
if ($LASTEXITCODE -ne 0) { throw '更新失敗。導入は実行しません。' }
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$repo\scripts\install.ps1"
if ($LASTEXITCODE -eq 2) { throw '既存AGENTS.mdとの差分を確認してください（後述）。' }
if ($LASTEXITCODE -ne 0) { throw '導入失敗。' }
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$repo\scripts\verify.ps1"
if ($LASTEXITCODE -ne 0) { throw '配置検証失敗。' }
```

## 3. 既存AGENTS.mdとの差分で停止した場合

空の既存ファイルも保護します。終了コード2は想定した保護動作です。まず差分を確認してください。Gitの差分終了コードは0=同一、1=差分あり、その他=エラーです。ページャーは使わず表示します。

```powershell
$ErrorActionPreference = 'Stop'
$repo = Join-Path $HOME 'Codex_MultiAgent'
Set-Location -LiteralPath $repo
. "$repo\scripts\common.ps1"
$paths = Get-PolicyPaths
git --no-pager diff --no-index -- "$($paths.Target)" "$($paths.Source)"
if ($LASTEXITCODE -notin @(0, 1)) { throw '差分表示失敗。' }
```

独自ルールを残す場合は手動で統合してください。統合版は共通版と異なるので、`verify.ps1`は不一致になります。**共通版への全置換を選ぶ場合のみ**以下を実行します。毎回作業場所を指定しているため、別のターミナルからも実行できます。

```powershell
$ErrorActionPreference = 'Stop'
$repo = Join-Path $HOME 'Codex_MultiAgent'
Set-Location -LiteralPath $repo
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$repo\scripts\install.ps1" -Force
if ($LASTEXITCODE -ne 0) { throw '置換失敗。' }
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$repo\scripts\verify.ps1"
if ($LASTEXITCODE -ne 0) { throw '配置検証失敗。' }
```

差分がある既存ファイルは`<配布先>\backups\multiagent-日時-識別子\AGENTS.md`へコピーし、SHA256一致を確認してから置換します。バックアップに失敗した場合は置換しません。配置時は同じディレクトリに一時ファイルを作成し、ハッシュ確認後に置換します。既存ファイルのハードリンク先も上書きしません。同一内容なら`-Force`でも変更・追加バックアップはしません。表示された`Backup:`の場所を保存してください。復元は、そのバックアップの`AGENTS.md`を表示された配布先へ戻します（復元後、共通版との不一致は正常です）。

プレビューは、上の置換ブロックのインストール行に`-WhatIf`を追加して実行できます。ファイルやバックアップは作成しません。プレビュー後に検証しても未導入・旧版なら失敗します。

## 4. 導入後の確認

`verify.ps1`が確認するのは配布元・配布先のSHA256一致です。マルチエージェント機能の有効化や実行成功を意味しません。スクリプトは`config.toml`を変更しないため、必要な機能設定は各PCのCodex仕様に従って個別に扱います。

新しいCodexセッションをリポジトリで開き、次を依頼します。

> ファイルや設定、Gitは変更せず、読み取り専用で確認してください。今回読み込まれたグローバルAGENTS.mdの方針を確認し、利用可能ならREADME系ファイルの名前を調べる調査をサブエージェントに1件委任してください。利用可能なモデル・推論強度から選び、指定値と選定理由、起動・完了結果、調査結果を報告してください。実行時の実適用値を裏付ける情報がなければ「確認できない」と明記してください。委任機能が利用できない場合はその制約を報告し、設定は変更しないでください。

通常の運用では単純な作業を直接処理して構いません。上記は委任の動作確認用です。モデル名・推論強度の指定受理と、実行時の実適用確認を区別します。利用可能な選択肢は環境ごとに確認し、固定しません。

### これまでの実績と制限

- Windows PowerShell 5.1でUTF-8 BOMなしの日本語スクリプトが文字化けした経緯を踏まえ、`.ps1`はUTF-8 BOM付き・ASCIIメッセージで保存します。日本語手順はREADMEに記載します。
- `C:\Users\user`から相対指定`.\scripts\install.ps1`を実行するとファイルが見つからず失敗。今回は移動先の明記と絶対指定を併用します。スクリプト内部は`$PSScriptRoot`で配布元を解決します。
- 空の既存AGENTS.mdとの差分停止後、`-Force`によるバックアップ・導入成功が報告されています（2026-10-15）。
- 同日の読み取り専用委任は`gpt-6-luna` / `low`を指定して起動・完了し、結果は`README.md`。実行時のモデル・推論強度は確認できていません。これは過去の報告であり、全PCの動作保証ではありません。

## 管理対象・終了コード

| 対象 | 扱い |
|---|---|
| `policy/AGENTS.md` | 共通方針。内容は今回変更しない |
| `scripts/common.ps1` | 配布先とパスの検証 |
| `scripts/install.ps1` | 配置・差分保護・バックアップ。0=成功/同一/WhatIf、2=既存差分、1=エラー |
| `scripts/verify.ps1` | 配置ハッシュ確認。0=一致、1=不一致/未導入/エラー |
| `tests/smoke.ps1` | 一時配布先での回帰検証。実際のCodex設定は使わない |
| `config.toml`、認証、鍵、履歴 | 配布・同期・コミット対象外 |
| プロジェクト内`AGENTS.md` | 各プロジェクトで管理 |

[OpenAI公式のAGENTS.md説明](https://learn.chatgpt.com/docs/agent-configuration/agents-md)にあるとおり、グローバル方針とプロジェクト側の指示が適用されます。既存の`AGENTS.override.md`やプロジェクトの指示によって挙動が変わる場合があります。このリポジトリは機能の追加やモデル選択の実適用を保証するものではありません。

`-ExecutionPolicy Bypass`は起動するプロセスだけの指定です。永続設定を変更せず、組織の強制ポリシーには従います。Commit・PushなどのGit書き込みはユーザーの明示的許可が必要です。

## 開発時の回帰検証

```powershell
$ErrorActionPreference = 'Stop'
$repo = Join-Path $HOME 'Codex_MultiAgent'
Set-Location -LiteralPath $repo
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$repo\tests\smoke.ps1"
if ($LASTEXITCODE -ne 0) { throw '回帰検証失敗。' }
```

2026-10-15にWindows PowerShell 5.1で回帰検証済みです。日本語・空白パス、カレントディレクトリ違い、初回・同一内容・差分停止、WhatIf、空/非空バックアップ、バックアップ失敗時の保持、設定・認証のテストファイル保持、ハードリンク先保持、ジャンクション拒否、BOM・構文を確認しました。PowerShell 7での実行と、この変更後のCodex内委任テストは未実施です。
