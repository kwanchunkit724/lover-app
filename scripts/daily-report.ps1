# Daily lover-app status report.
# Runs via Windows Task Scheduler at 6:03 am every morning.
# Invokes `claude -p` headless against PLAN.md + git + GHA, writes the
# Markdown to a dated file, then pops a Windows toast / msg with the first
# few lines as a preview.

$ErrorActionPreference = 'Continue'
$repo  = 'C:\Users\user\lover-app'
$today = Get-Date -Format 'yyyy-MM-dd'
$out   = Join-Path $repo ".daily-reports\$today.md"
$dir   = Split-Path $out -Parent
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }

$prompt = @'
Produce a daily status report for the **lover-app** project (iOS SwiftUI + Android Compose, Supabase backend, cross-platform IG-style chat couples app). Reply in Traditional Chinese (HK), caveman-terse (drop articles/filler, fragments OK, tech terms exact).

Read these in order:
1. C:\Users\user\lover-app\PLAN.md
2. git -C C:\Users\user\lover-app log --oneline -20
3. git -C C:\Users\user\lover-app status
4. curl https://api.github.com/repos/kwanchunkit724/lover-app/actions/runs?per_page=10
5. C:\Users\user\lover-app\BUG-AUDIT-v1.5.1.md if exists
6. C:\Users\user\lover-app\android\PHASE-*.md

Report structure (under 400 words):

```
# 早安 — Lover-app 進度 [YYYY-MM-DD]

## 北極星
[1 line]

## 已完成 (✅)
[5-8 lines: checked PLAN.md items + recent commits]

## 進行緊 (🟡)
[uncommitted changes, in-progress GHA runs, current milestone unchecked items]

## 未開始 (⏳)
[next 3-5 pending items in dependency order]

## 阻塞 / 需要你決定
[anything needing user input]

## 建議今日做
[1-2 specific actions, ranked by impact-vs-effort]
```

Ruthlessly terse. No filler. Tables OK.
'@

Push-Location $repo
try {
    # `claude -p` runs the prompt non-interactively and prints the final answer to stdout.
    # `--dangerously-skip-permissions` so unattended runs don't block on permission prompts.
    $report = & claude -p $prompt --dangerously-skip-permissions 2>&1 | Out-String
    Set-Content -Path $out -Value $report -Encoding UTF8

    # Preview: first 14 lines.
    $preview = (Get-Content $out -TotalCount 14) -join "`r`n"

    # Windows toast via msg.exe (legacy but always available).
    $msgText = "Lover-app daily report ready.`r`n`r`n$preview`r`n`r`nFull: $out"
    Start-Process -FilePath "msg.exe" -ArgumentList "* /TIME:60 `"$msgText`"" -WindowStyle Hidden -ErrorAction SilentlyContinue
}
finally {
    Pop-Location
}
