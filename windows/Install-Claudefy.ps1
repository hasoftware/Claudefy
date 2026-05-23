#Requires -Version 7

<#
.SYNOPSIS
    Claudefy installer - make Claude Code yours.

.NOTES
    Author     : Hoang Anh Dev
    Admin      : HASOFTWARE
    Telegram   : https://t.me/hasoftware
    Repository : https://github.com/hasoftware/Claudefy

.DESCRIPTION
    All-in-one installer that customizes Claude Code on Windows:
      - JetBrainsMono Nerd Font (via winget)
      - Powerline-style statusLine (up to 3 lines) showing:
          Line 1: folder | git | runtime | stash | commit-age | PR/CI | model | clock
          Line 2: context% | 5h% | 7d% | Opus 7d% | cost | lines | tokens
          Line 3: total LOC of project (requires DevRadar — optional)
      - Stop hook: notification + quota alerts when Claude finishes
      - SessionStart hook: dynamic Windows Terminal tab title per project
      - Sequential-thinking MCP server (optional)
      - DevRadar code analyzer for Line 3 LOC widget (optional)
      - Sensible permission allowlist (~50 read-only commands)
      - Windows Terminal font configured to JetBrainsMono Nerd Font

    Safe to re-run: existing config files are backed up with .backup-<timestamp>.
    Existing settings.json fields are preserved; only our keys are merged in.

.PARAMETER Force
    Skip all confirmation prompts.

.PARAMETER SkipFont
    Don't install or configure the Nerd Font.

.PARAMETER SkipWindowsTerminal
    Don't modify Windows Terminal settings.json.

.PARAMETER SkipMCP
    Don't register MCP servers.

.PARAMETER SkipDevRadar
    Don't prompt to install DevRadar (Line 3 LOC widget will stay disabled until installed manually with `npm install -g devradar`).

.EXAMPLE
    .\Install-Claudefy.ps1

.EXAMPLE
    .\Install-Claudefy.ps1 -Force -SkipFont
#>

[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$SkipFont,
    [switch]$SkipWindowsTerminal,
    [switch]$SkipMCP,
    [switch]$SkipDevRadar
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding           = [System.Text.UTF8Encoding]::new($false)

# ============================================================================
# UI helpers
# ============================================================================
function Write-Section([string]$title) {
    Write-Host ""
    Write-Host ("=" * 60)         -ForegroundColor DarkCyan
    Write-Host "  $title"         -ForegroundColor Cyan
    Write-Host ("=" * 60)         -ForegroundColor DarkCyan
}
function Write-Step([string]$msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok  ([string]$msg) { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn([string]$msg) { Write-Host "  [!]  $msg" -ForegroundColor Yellow }
function Write-Err ([string]$msg) { Write-Host "  [X]  $msg" -ForegroundColor Red }
function Write-Info([string]$msg) { Write-Host "       $msg" -ForegroundColor DarkGray }

function Confirm-Action([string]$msg, [string]$default = 'Y') {
    if ($Force) { return $true }
    $prompt = if ($default -eq 'Y') { "$msg [Y/n] " } else { "$msg [y/N] " }
    $answer = Read-Host -Prompt $prompt
    if (-not $answer) { $answer = $default }
    return $answer -match '^[Yy]'
}

function Backup-File([string]$path) {
    if (Test-Path $path) {
        $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
        $backup = "$path.backup-$ts"
        Copy-Item -Path $path -Destination $backup -Force
        Write-Info "Backed up -> $backup"
    }
}

# ============================================================================
# Welcome
# ============================================================================
Write-Section "Claudefy Installer - make Claude Code yours"
Write-Host "  by Hoang Anh Dev - HASOFTWARE" -ForegroundColor DarkGray
Write-Host "  https://t.me/hasoftware  |  https://github.com/hasoftware/Claudefy" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  - Powerline statusLine (up to 3 lines, full info)"
Write-Host "  - JetBrainsMono Nerd Font"
Write-Host "  - Hooks: notification + dynamic tab title + quota alerts"
Write-Host "  - MCP: sequential-thinking"
Write-Host "  - DevRadar: optional Line 3 LOC widget (asks before install)"
Write-Host "  - Permission allowlist"

if (-not (Confirm-Action "`nProceed with install?")) {
    Write-Host "Cancelled." -ForegroundColor Yellow
    exit 0
}

# ============================================================================
# 1. Pre-flight checks
# ============================================================================
Write-Section "1. Pre-flight checks"

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Err "PowerShell 7+ required. Install: winget install Microsoft.PowerShell"
    exit 1
}
Write-Ok "PowerShell $($PSVersionTable.PSVersion)"

$claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
if (-not $claudeCmd) {
    Write-Err "Claude Code CLI not found. Install from https://claude.com/claude-code"
    exit 1
}
Write-Ok "Claude Code: $($claudeCmd.Source)"

$gitCmd  = Get-Command git  -ErrorAction SilentlyContinue
$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
$ghCmd   = Get-Command gh   -ErrorAction SilentlyContinue
$wingetCmd = Get-Command winget -ErrorAction SilentlyContinue

if ($gitCmd)  { Write-Ok "git: $($gitCmd.Source)" }      else { Write-Warn "git not found (git features disabled in statusLine)" }
if ($nodeCmd) { Write-Ok "node: $(node --version)" }     else { Write-Warn "node not found (MCP servers will not run)" }
if ($ghCmd)   { Write-Ok "gh: $($ghCmd.Source)" }        else { Write-Warn "gh CLI not found (PR/CI block disabled)" }
if ($wingetCmd -or $SkipFont) { } else { Write-Warn "winget not found (cannot auto-install font)" }

$claudeDir = Join-Path $env:USERPROFILE '.claude'
if (-not (Test-Path $claudeDir)) {
    New-Item -ItemType Directory -Path $claudeDir | Out-Null
    Write-Ok "Created $claudeDir"
}

# ============================================================================
# 2. Install JetBrainsMono Nerd Font
# ============================================================================
if (-not $SkipFont) {
    Write-Section "2. Install JetBrainsMono Nerd Font"

    $hasNerdFont = $false
    try {
        $shellApp = New-Object -ComObject Shell.Application
        $fontsFolder = $shellApp.NameSpace(0x14)
        $fonts = @($fontsFolder.Items() | ForEach-Object { $_.Name })
        $hasNerdFont = ($fonts | Where-Object { $_ -match 'JetBrainsMono.*Nerd' }).Count -gt 0
    } catch {}

    if ($hasNerdFont) {
        Write-Ok "Already installed"
    } elseif ($wingetCmd) {
        Write-Step "Installing via winget (~112 MB, may prompt for elevation)"
        & winget install DEVCOM.JetBrainsMonoNerdFont --silent --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -eq 0) { Write-Ok "Installed" } else { Write-Warn "winget returned $LASTEXITCODE - check output above" }
    } else {
        Write-Warn "Skipped: winget not available. Install manually from https://www.nerdfonts.com/font-downloads"
    }
} else {
    Write-Section "2. Install JetBrainsMono Nerd Font"
    Write-Info "Skipped (-SkipFont)"
}

# ============================================================================
# 3. Write helper scripts (statusline, notify-stop, set-title)
# ============================================================================
Write-Section "3. Write helper scripts to $claudeDir"

# --- statusline-command.ps1 -----------------------------------------------
$STATUSLINE_PS1 = @'
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding           = [System.Text.UTF8Encoding]::new($false)

$raw = [Console]::In.ReadToEnd()
if (-not $raw) { return }
try { $d = $raw | ConvertFrom-Json } catch { return }

# Optional debug: uncomment to capture full JSON for inspection
# $raw | Out-File -Encoding utf8 "$env:TEMP\claude-statusline-input.json"

$e = [char]27
$NF_FOLDER   = [char]0xF07B
$NF_GIT      = [char]0xE725
$NF_CHIP     = [char]0xF2DB
$NF_BRAIN    = [char]0xF06E
$NF_TIMER    = [char]0xF252
$NF_CAL      = [char]0xF073
$NF_STAR     = [char]0xF005
$NF_HASH     = [char]0xF292
$NF_USD      = [char]0xF155
$NF_PEN      = [char]0xF040
$NF_CLOCK    = [char]0xF017
$NF_HISTORY  = [char]0xF1DA
$NF_STASH    = [char]0x21A9
$NF_PR       = [char]0xF407
$NF_NODE     = [char]0xE718
$NF_PYTHON   = [char]0xE235
$NF_RUST     = [char]0xE7A8
$NF_GO       = [char]0xE626
$NF_DOTNET   = [char]0xE77F
$NF_JAVA     = [char]0xE738
$NF_RUBY     = [char]0xE739
$NF_FLUTTER  = [char]0xE28E
$NF_CODE     = [char]0xF121
$NF_CUBE     = [char]0xF1B2
$NF_PIE      = [char]0xF200
$NF_ARROW    = [char]0xE0B0

function BgUsed([double]$pct, [int]$goodColor = 22) {
  if ($pct -ge 80) { return 88 }
  if ($pct -ge 50) { return 130 }
  return $goodColor
}
function BgRemaining([double]$pct, [int]$goodColor = 22) {
  if ($pct -le 20) { return 88 }
  if ($pct -le 50) { return 130 }
  return $goodColor
}
function ToHanoi($val) {
  if ($null -eq $val) { return $null }
  try {
    $utc = $null
    if ($val -is [long] -or $val -is [int] -or $val -is [double] -or $val -is [decimal]) {
      $utc = [DateTimeOffset]::FromUnixTimeSeconds([long]$val).UtcDateTime
    } else {
      $s = "$val"
      $epoch = 0L
      if ([long]::TryParse($s, [ref]$epoch)) {
        $utc = [DateTimeOffset]::FromUnixTimeSeconds($epoch).UtcDateTime
      } else {
        $utc = [datetime]::Parse($s, $null, [System.Globalization.DateTimeStyles]::AdjustToUniversal -bor [System.Globalization.DateTimeStyles]::AssumeUniversal)
      }
    }
    return $utc.AddHours(7).ToString('HH:mm')
  } catch { return $null }
}

function RenderPowerline($segs) {
  if ($segs.Count -eq 0) { return "" }
  $sb = New-Object System.Text.StringBuilder
  $prevBg = $null
  foreach ($s in $segs) {
    if ($null -ne $prevBg) {
      [void]$sb.Append("$e[38;5;${prevBg};48;5;$($s.bg)m${NF_ARROW}")
    }
    [void]$sb.Append("$e[48;5;$($s.bg);38;5;$($s.fg)m$($s.text)")
    $prevBg = $s.bg
  }
  [void]$sb.Append("$e[0m$e[38;5;${prevBg}m${NF_ARROW}$e[0m")
  return $sb.ToString()
}

$cwd   = $d.workspace.current_dir; if (-not $cwd) { $cwd = $d.cwd }
$dir   = if ($cwd) { Split-Path -Leaf $cwd } else { '?' }
$model = if ($d.model.display_name) { $d.model.display_name } else { 'Claude' }

# === LINE 1: Workspace context ===========================================
$line1 = @()
$line1 += @{ bg = 24; fg = 15; text = " $NF_FOLDER $dir " }

$branch = $null
if ($cwd -and (Test-Path $cwd)) {
  $branch = & git -C $cwd symbolic-ref --short HEAD 2>$null
  if (-not $branch) { $branch = & git -C $cwd rev-parse --short HEAD 2>$null }
  if ($branch) {
    $dirty = (& git -C $cwd status --porcelain 2>$null | Measure-Object).Count
    $ahead = 0; $behind = 0
    $rev = & git -C $cwd rev-list --left-right --count "HEAD...@{upstream}" 2>$null
    if ($rev) {
      $rp = $rev -split '\s+'
      if ($rp.Count -ge 2) { $ahead = [int]$rp[0]; $behind = [int]$rp[1] }
    }
    $gtxt = "$NF_GIT $branch"
    if ($dirty -gt 0) { $gtxt += " " + [char]0x25CF + "$dirty" } else { $gtxt += " " + [char]0x25CB }
    if ($ahead  -gt 0) { $gtxt += " " + [char]0x2191 + "$ahead" }
    if ($behind -gt 0) { $gtxt += " " + [char]0x2193 + "$behind" }
    $gbg = 28
    if ($dirty -gt 0)  { $gbg = 130 }
    if ($behind -gt 0) { $gbg = 88 }
    $line1 += @{ bg = $gbg; fg = 15; text = " $gtxt " }

    $stashCount = (& git -C $cwd stash list 2>$null | Measure-Object).Count
    if ($stashCount -gt 0) {
      $line1 += @{ bg = 53; fg = 15; text = " $NF_STASH $stashCount " }
    }

    $lastCommit = & git -C $cwd log -1 --format=%cr 2>$null
    if ($lastCommit) {
      $short = $lastCommit
      $short = $short -replace ' ago$',''
      $short = $short -replace ' hours?$','h' -replace ' minutes?$','m'
      $short = $short -replace ' days?$','d'  -replace ' weeks?$','w'
      $short = $short -replace ' months?$','mo' -replace ' years?$','y'
      $short = $short -replace ' seconds?$','s'
      $line1 += @{ bg = 240; fg = 15; text = " $NF_HISTORY $short " }
    }
  }
}

# Runtime detection
$runtime = $null
if ($cwd -and (Test-Path $cwd)) {
  if (Test-Path (Join-Path $cwd 'package.json')) {
    $v = & node --version 2>$null
    if ($v) { $runtime = @{ icon = $NF_NODE; name = ("Node " + ($v -replace '^v','')) } }
  }
  elseif ((Test-Path (Join-Path $cwd 'pyproject.toml')) -or (Test-Path (Join-Path $cwd 'requirements.txt')) -or (Test-Path (Join-Path $cwd 'setup.py')) -or (Test-Path (Join-Path $cwd 'Pipfile'))) {
    $v = & python --version 2>$null
    if (-not $v) { $v = & python3 --version 2>$null }
    if ($v -and $v -match 'Python (\d+\.\d+(\.\d+)?)') {
      $runtime = @{ icon = $NF_PYTHON; name = "Py $($Matches[1])" }
    }
  }
  elseif (Test-Path (Join-Path $cwd 'Cargo.toml')) {
    $v = & rustc --version 2>$null
    if ($v -and $v -match 'rustc (\d+\.\d+\.\d+)') {
      $runtime = @{ icon = $NF_RUST; name = "Rust $($Matches[1])" }
    }
  }
  elseif (Test-Path (Join-Path $cwd 'go.mod')) {
    $v = & go version 2>$null
    if ($v -and $v -match 'go(\d+\.\d+(\.\d+)?)') {
      $runtime = @{ icon = $NF_GO; name = "Go $($Matches[1])" }
    }
  }
  elseif (Test-Path (Join-Path $cwd 'pubspec.yaml')) {
    $v = & flutter --version 2>$null
    if ($v -and $v -match 'Flutter (\d+\.\d+\.\d+)') {
      $runtime = @{ icon = $NF_FLUTTER; name = "Flutter $($Matches[1])" }
    }
  }
  elseif ((Get-ChildItem $cwd -Filter '*.csproj' -ErrorAction SilentlyContinue | Select-Object -First 1) -or
          (Get-ChildItem $cwd -Filter '*.sln'    -ErrorAction SilentlyContinue | Select-Object -First 1)) {
    $v = & dotnet --version 2>$null
    if ($v) { $runtime = @{ icon = $NF_DOTNET; name = ".NET $v" } }
  }
  elseif ((Test-Path (Join-Path $cwd 'pom.xml')) -or (Test-Path (Join-Path $cwd 'build.gradle')) -or (Test-Path (Join-Path $cwd 'build.gradle.kts'))) {
    $v = & java --version 2>$null | Select-Object -First 1
    if ($v -and $v -match '(\d+\.\d+\.\d+)') {
      $runtime = @{ icon = $NF_JAVA; name = "Java $($Matches[1])" }
    }
  }
  elseif (Test-Path (Join-Path $cwd 'Gemfile')) {
    $v = & ruby --version 2>$null
    if ($v -and $v -match 'ruby (\d+\.\d+\.\d+)') {
      $runtime = @{ icon = $NF_RUBY; name = "Ruby $($Matches[1])" }
    }
  }
}
if ($runtime) {
  $line1 += @{ bg = 24; fg = 15; text = " $($runtime.icon) $($runtime.name) " }
}

# PR + CI status (cached 60s)
if ($branch -and (Get-Command gh -ErrorAction SilentlyContinue)) {
  $cacheKey = ($cwd + '|' + $branch) -replace '[\\/:*?"<>|]','_'
  $cacheFile = "$env:TEMP\claude-pr-cache-$cacheKey.json"
  $pr = $null
  if (Test-Path $cacheFile) {
    try {
      $cache = Get-Content $cacheFile -Raw | ConvertFrom-Json
      $age = (Get-Date).ToUniversalTime() - ([datetime]$cache.timestamp).ToUniversalTime()
      if ($age.TotalSeconds -lt 60) { $pr = $cache.pr }
    } catch {}
  }
  if (-not $pr) {
    try {
      $prJsonRaw = & gh pr list --head $branch --state open --json number,statusCheckRollup,reviewDecision -L 1 2>$null
      if ($prJsonRaw) {
        $arr = $prJsonRaw | ConvertFrom-Json
        if ($arr -and $arr.Count -gt 0) { $pr = $arr[0] }
      }
      @{ timestamp = (Get-Date).ToUniversalTime().ToString('o'); pr = $pr } | ConvertTo-Json -Depth 10 | Set-Content $cacheFile -Encoding UTF8
    } catch {}
  }
  if ($pr) {
    $statusIcon = [char]0x25CB
    $prBg = 240
    if ($pr.statusCheckRollup -and $pr.statusCheckRollup.Count -gt 0) {
      $concl = $pr.statusCheckRollup | ForEach-Object { $_.conclusion } | Where-Object { $_ }
      if ($concl -contains 'FAILURE' -or $concl -contains 'CANCELLED' -or $concl -contains 'TIMED_OUT') {
        $statusIcon = [char]0x2717; $prBg = 88
      } elseif (($concl | Where-Object { $_ -ne 'SUCCESS' -and $_ -ne 'NEUTRAL' -and $_ -ne 'SKIPPED' }).Count -gt 0) {
        $statusIcon = [char]0x231B; $prBg = 130
      } else {
        $statusIcon = [char]0x2713; $prBg = 22
      }
    }
    $line1 += @{ bg = $prBg; fg = 15; text = " $NF_PR #$($pr.number) $statusIcon " }
  }
}

$line1 += @{ bg = 208; fg = 0; text = " $NF_CHIP $model " }

$nowHanoi = (Get-Date).ToUniversalTime().AddHours(7).ToString('HH:mm')
$timeStr = "$nowHanoi ICT"
$durMs = $d.cost.total_duration_ms
if ($null -ne $durMs) {
  $totalMin = [math]::Floor([double]$durMs / 60000)
  $h = [math]::Floor($totalMin / 60)
  $m = $totalMin % 60
  $dur = if ($h -gt 0) { "${h}h${m}m" } else { "${m}m" }
  $timeStr += " ($dur)"
}
$line1 += @{ bg = 236; fg = 15; text = " $NF_CLOCK $timeStr " }

# Claudefy update check (cached 24h)
$CLAUDEFY_VER = '1.2.0'
$updateAvail = $null
try {
  $ucFile = "$env:TEMP\claudefy-update-check.json"
  $latestVer = $null; $needCheck = $true
  if (Test-Path $ucFile) {
    $uc = Get-Content $ucFile -Raw | ConvertFrom-Json
    $ucAge = (Get-Date).ToUniversalTime() - ([datetime]$uc.timestamp).ToUniversalTime()
    if ($ucAge.TotalSeconds -lt 86400) { $needCheck = $false; $latestVer = $uc.latest_version }
  }
  if ($needCheck) {
    $rel = Invoke-RestMethod 'https://api.github.com/repos/hasoftware/Claudefy/releases/latest' -Headers @{'User-Agent'='Claudefy'} -TimeoutSec 3 -ErrorAction Stop
    $latestVer = $rel.tag_name -replace '^v',''
    @{ timestamp = (Get-Date).ToUniversalTime().ToString('o'); latest_version = $latestVer } | ConvertTo-Json | Set-Content $ucFile -Encoding UTF8
  }
  if ($latestVer -and ([version]$latestVer -gt [version]$CLAUDEFY_VER)) { $updateAvail = $latestVer }
} catch {}
if ($updateAvail) {
  $line1 += @{ bg = 166; fg = 15; text = " $([char]0x2B06) v$updateAvail " }
}

# .env safety check (cached 5min)
$envWarning = $false
if ($cwd -and (Test-Path $cwd)) {
  $envCK = ($cwd) -replace '[\\/:*?"<>|]','_'
  $envCF = "$env:TEMP\claudefy-env-$envCK.txt"
  $needEC = $true
  if (Test-Path $envCF) {
    $ecAge = (Get-Date).ToUniversalTime() - (Get-Item $envCF).LastWriteTimeUtc
    if ($ecAge.TotalSeconds -lt 300) { $needEC = $false; $envWarning = (Get-Content $envCF -Raw).Trim() -eq '1' }
  }
  if ($needEC) {
    $envFs = Get-ChildItem $cwd -Filter '.env*' -File -ErrorAction SilentlyContinue
    foreach ($ef in $envFs) {
      $ign = & git -C $cwd check-ignore $ef.Name 2>$null
      if (-not $ign) { $envWarning = $true; break }
    }
    Set-Content $envCF -Value $(if ($envWarning) {'1'} else {'0'}) -Encoding UTF8
  }
}
if ($envWarning) {
  $line1 += @{ bg = 88; fg = 15; text = " $([char]0x26A0) .env " }
}

# === LINE 2: Resource usage ==============================================
$line2 = @()

$ctx = $d.context_window.remaining_percentage
if ($null -ne $ctx) {
  $bg = BgRemaining ([double]$ctx) 29
  $line2 += @{ bg = $bg; fg = 15; text = (" $NF_BRAIN Context: {0:N0}% " -f [double]$ctx) }
}

$fh = $d.rate_limits.five_hour.used_percentage
if ($null -ne $fh) {
  $bg = BgUsed ([double]$fh) 22
  $txt = " $NF_TIMER 5h: {0:N0}%" -f [double]$fh
  $resetTime = ToHanoi $d.rate_limits.five_hour.resets_at
  if ($resetTime) { $txt += " " + [char]0x2192 + "$resetTime" }
  $txt += " "
  $line2 += @{ bg = $bg; fg = 15; text = $txt }
}

$sd = $d.rate_limits.seven_day.used_percentage
$sdLabel = "7d"
$sdReset = $d.rate_limits.seven_day.resets_at
if ($null -ne $sdReset) {
  try {
    $nowUnix = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $remDays = [math]::Ceiling(([long]$sdReset - $nowUnix) / 86400.0)
    if ($remDays -ge 1 -and $remDays -le 7) { $sdLabel = "${remDays}d" }
  } catch {}
}
if ($null -ne $sd) {
  $bg = BgUsed ([double]$sd) 28
  $line2 += @{ bg = $bg; fg = 15; text = (" $NF_CAL ${sdLabel}: {0:N0}% " -f [double]$sd) }
}

$op = $d.rate_limits.seven_day_opus.used_percentage
if ($null -ne $op) {
  $bg = BgUsed ([double]$op) 65
  $line2 += @{ bg = $bg; fg = 15; text = (" $NF_STAR Opus ${sdLabel}: {0:N0}% " -f [double]$op) }
}

$cost = $d.cost.total_cost_usd
if ($null -ne $cost) {
  $cstr = "{0:N2}" -f [double]$cost
  $line2 += @{ bg = 94; fg = 15; text = " $NF_USD `$$cstr " }
}

$added   = $d.cost.total_lines_added
$removed = $d.cost.total_lines_removed
if (($null -ne $added) -or ($null -ne $removed)) {
  $a = if ($null -ne $added)   { [int]$added }   else { 0 }
  $r = if ($null -ne $removed) { [int]$removed } else { 0 }
  $line2 += @{ bg = 22; fg = 15; text = " $NF_PEN +$a -$r " }
}

$tok = $null
$inTok  = $d.context_window.total_input_tokens
$outTok = $d.context_window.total_output_tokens
if ($null -ne $inTok -or $null -ne $outTok) {
  $a = if ($null -ne $inTok)  { [double]$inTok }  else { 0 }
  $b = if ($null -ne $outTok) { [double]$outTok } else { 0 }
  $tok = $a + $b
}
if ($null -ne $tok) {
  $human = if ($tok -ge 1e6) { ("{0:N1}M" -f ($tok/1e6)) }
           elseif ($tok -ge 1e3) { ("{0:N1}k" -f ($tok/1e3)) }
           else { ("{0:N0}" -f $tok) }
  $line2 += @{ bg = 24; fg = 15; text = " $NF_HASH $human " }
}

# Turns (from transcript)
$tp = $d.transcript_path
if ($tp -and (Test-Path $tp)) {
  $turns = (Select-String -Path $tp -Pattern '"type":"human"' -SimpleMatch | Measure-Object).Count
  if ($turns -gt 0) {
    $line2 += @{ bg = 24; fg = 15; text = " $([char]0xF075) $turns turns " }
  }
}

# === LINE 3: Project DNA (DevRadar — cached by git HEAD, TTL 10min) ======
$line3 = @()
if ($cwd -and (Test-Path $cwd) -and (Get-Command devradar -ErrorAction SilentlyContinue)) {
  $headSha = & git -C $cwd rev-parse HEAD 2>$null
  $cacheKeyRaw = if ($headSha) { "$cwd|$headSha" } else { $cwd }
  $cacheKey = $cacheKeyRaw -replace '[\\/:*?"<>|]','_'
  $cacheFile = "$env:TEMP\claude-devradar-cache-$cacheKey.json"
  $devradar = $null
  if (Test-Path $cacheFile) {
    try {
      $cache = Get-Content $cacheFile -Raw | ConvertFrom-Json
      $age = (Get-Date).ToUniversalTime() - ([datetime]$cache.timestamp).ToUniversalTime()
      if ($age.TotalSeconds -lt 600) { $devradar = $cache.data }
    } catch {}
  }
  if (-not $devradar) {
    try {
      $json = & devradar --format json "$cwd" 2>$null
      if ($json) {
        $devradar = $json | ConvertFrom-Json
        @{ timestamp = (Get-Date).ToUniversalTime().ToString('o'); data = $devradar } | ConvertTo-Json -Depth 10 | Set-Content $cacheFile -Encoding UTF8
      }
    } catch {}
  }
  if ($devradar -and $devradar.summary.codeLines) {
    if ($devradar.technologies.frameworks -and $devradar.technologies.frameworks.Count -gt 0) {
      $fwList = ($devradar.technologies.frameworks -join [char]0x00B7)
      $line3 += @{ bg = 60; fg = 15; text = " $NF_CUBE $fwList " }
    }

    $loc = [int]$devradar.summary.codeLines
    $locStr = if ($loc -ge 1e6) { "{0:N1}M" -f ($loc/1e6) }
              elseif ($loc -ge 1e3) { "{0:N1}k" -f ($loc/1e3) }
              else { "$loc" }
    $line3 += @{ bg = 23; fg = 15; text = " $NF_CODE $locStr Lines " }

    $totalLines = [double]$devradar.summary.totalLines
    if ($totalLines -gt 0) {
      $ratio = [math]::Round(([double]$devradar.summary.codeLines / $totalLines) * 100)
      $line3 += @{ bg = 25; fg = 15; text = " $NF_PIE $ratio% code " }
    }
  }
}

# === LINE 4: Branding ======================================================
$line4 = @()
$line4 += @{ bg = 237; fg = 75; text = " Claudefy v$CLAUDEFY_VER " }
$line4 += @{ bg = 237; fg = 208; text = " Author: HoangAnhDev " }

$out1 = RenderPowerline $line1
$out2 = RenderPowerline $line2
$out4 = RenderPowerline $line4
if ($line3.Count -gt 0) {
  $out3 = RenderPowerline $line3
  [Console]::Out.Write("$out1`n$out2`n$out3`n$out4")
} else {
  [Console]::Out.Write("$out1`n$out2`n$out4")
}
'@

$statuslinePath = Join-Path $claudeDir 'statusline-command.ps1'
Backup-File $statuslinePath
Set-Content -Path $statuslinePath -Value $STATUSLINE_PS1 -Encoding UTF8
Write-Ok "statusline-command.ps1"

# --- notify-stop.ps1 ------------------------------------------------------
$NOTIFY_PS1 = @'
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$raw = [Console]::In.ReadToEnd()
$d = try { $raw | ConvertFrom-Json } catch { $null }

# Thresholds — edit freely
$T_5H        = 80
$T_7D        = 80
$T_OPUS_7D   = 80
$T_CONTEXT   = 10
$T_COST_USD  = 5.0

$warnings = @()
$fh = $d.rate_limits.five_hour.used_percentage
if ($null -ne $fh -and [double]$fh -ge $T_5H)        { $warnings += ("5h quota {0:N0}%" -f [double]$fh) }
$sd = $d.rate_limits.seven_day.used_percentage
if ($null -ne $sd -and [double]$sd -ge $T_7D)        { $warnings += ("7d quota {0:N0}%" -f [double]$sd) }
$op = $d.rate_limits.seven_day_opus.used_percentage
if ($null -ne $op -and [double]$op -ge $T_OPUS_7D)   { $warnings += ("Opus 7d {0:N0}%" -f [double]$op) }
$ctx = $d.context_window.remaining_percentage
if ($null -ne $ctx -and [double]$ctx -le $T_CONTEXT) { $warnings += ("Context only {0:N0}% left" -f [double]$ctx) }
$cost = $d.cost.total_cost_usd
if ($null -ne $cost -and [double]$cost -ge $T_COST_USD) { $warnings += ("Cost `${0:N2}" -f [double]$cost) }

$project = if ($d.workspace.current_dir) { Split-Path -Leaf $d.workspace.current_dir }
           elseif ($d.cwd) { Split-Path -Leaf $d.cwd }
           else { 'Claude' }

if ($warnings.Count -gt 0) {
  $msg = "[!] $project - " + ($warnings -join '; ')
  $beepCount = 3
} else {
  $msg = "$project - Claude is ready"
  $beepCount = 1
}

$esc = [char]27
$bel = [char]7
$osc9  = "${esc}]9;${msg}${bel}"
$bells = $bel * $beepCount
$seq   = "${osc9}${bells}"

@{ terminalSequence = $seq } | ConvertTo-Json -Compress
'@

$notifyPath = Join-Path $claudeDir 'notify-stop.ps1'
Backup-File $notifyPath
Set-Content -Path $notifyPath -Value $NOTIFY_PS1 -Encoding UTF8
Write-Ok "notify-stop.ps1"

# --- set-title.ps1 --------------------------------------------------------
$SETTITLE_PS1 = @'
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$raw = [Console]::In.ReadToEnd()

# Optional debug: uncomment to capture full JSON for inspection
# $raw | Out-File -Encoding utf8 "$env:TEMP\claude-sessionstart-input.json"

$d = try { $raw | ConvertFrom-Json } catch { $null }

$esc = [char]27
$bel = [char]7

$project = if ($d.cwd) { Split-Path -Leaf $d.cwd }
           elseif ($d.workspace.current_dir) { Split-Path -Leaf $d.workspace.current_dir }
           else { 'Claude' }
$title = "$project - Claude Code"

$seq = "${esc}]2;${title}${bel}"
@{ terminalSequence = $seq } | ConvertTo-Json -Compress
'@

$titlePath = Join-Path $claudeDir 'set-title.ps1'
Backup-File $titlePath
Set-Content -Path $titlePath -Value $SETTITLE_PS1 -Encoding UTF8
Write-Ok "set-title.ps1"

# ============================================================================
# 4. Merge Claude Code settings.json
# ============================================================================
Write-Section "4. Merge Claude Code settings.json"

$settingsPath = Join-Path $claudeDir 'settings.json'
Backup-File $settingsPath

# Convert paths to forward slashes for JSON
$slPath  = $statuslinePath -replace '\\','/'
$ntPath  = $notifyPath    -replace '\\','/'
$ttPath  = $titlePath     -replace '\\','/'

# Load existing settings
$settings = [ordered]@{}
if (Test-Path $settingsPath) {
    try {
        $existing = Get-Content $settingsPath -Raw | ConvertFrom-Json -AsHashtable
        if ($existing) { $settings = [ordered]@{}; foreach ($k in $existing.Keys) { $settings[$k] = $existing[$k] } }
        Write-Info "Loaded existing settings.json"
    } catch {
        Write-Warn "Could not parse existing settings.json — starting fresh"
    }
}

# statusLine — replace
$settings['statusLine'] = [ordered]@{
    type    = 'command'
    command = "pwsh -NoProfile -File `"$slPath`""
}

# hooks — set ours (SessionStart + Stop), preserve other event hooks
if (-not $settings.Contains('hooks')) { $settings['hooks'] = [ordered]@{} }
$settings['hooks']['SessionStart'] = @(
    [ordered]@{
        matcher = ''
        hooks   = @(
            [ordered]@{ type = 'command'; command = "pwsh -NoProfile -File `"$ttPath`"" }
        )
    }
)
$settings['hooks']['Stop'] = @(
    [ordered]@{
        matcher = ''
        hooks   = @(
            [ordered]@{ type = 'command'; command = "pwsh -NoProfile -File `"$ntPath`"" }
        )
    }
)

# permissions.allow — additive merge with existing
$kitAllows = @(
    "Bash(git push:*)", "Bash(git push origin main)", "Bash(git push origin *)",
    "Bash(ls:*)", "Bash(pwd)", "Bash(cat:*)", "Bash(head:*)", "Bash(tail:*)",
    "Bash(file:*)", "Bash(wc:*)", "Bash(echo:*)", "Bash(date:*)", "Bash(which:*)",
    "Bash(env)", "Bash(printenv:*)",
    "Bash(git status:*)", "Bash(git log:*)", "Bash(git diff:*)",
    "Bash(git branch:*)", "Bash(git remote:*)", "Bash(git show:*)",
    "Bash(git fetch:*)", "Bash(git rev-parse:*)", "Bash(git rev-list:*)",
    "Bash(git symbolic-ref:*)", "Bash(git config --get:*)",
    "Bash(git stash list:*)", "Bash(git tag:*)", "Bash(git blame:*)",
    "Bash(git ls-files:*)", "Bash(git describe:*)",
    "Bash(node --version)", "Bash(npm --version)", "Bash(npm ls:*)",
    "Bash(npm run test:*)", "Bash(npm test:*)",
    "Bash(python --version)", "Bash(python -V)", "Bash(pip list:*)", "Bash(pip show:*)",
    "Bash(pwsh --version)", "Bash(git --version)", "Bash(gh --version)",
    "Bash(go version)", "Bash(cargo --version)", "Bash(rustc --version)",
    "Bash(gh pr list:*)", "Bash(gh pr view:*)", "Bash(gh pr diff:*)",
    "Bash(gh issue list:*)", "Bash(gh issue view:*)",
    "Bash(gh repo view:*)", "Bash(gh api repos:*)",
    "PowerShell(Get-Content:*)", "PowerShell(Get-ChildItem:*)",
    "PowerShell(Get-Command:*)", "PowerShell(Test-Path:*)",
    "PowerShell(Get-Date:*)", "PowerShell(Get-Item:*)",
    "PowerShell(Select-Object:*)", "PowerShell(Measure-Object:*)",
    "PowerShell(Get-Process:*)", "PowerShell(Get-Service:*)"
)

if (-not $settings.Contains('permissions')) { $settings['permissions'] = [ordered]@{ allow = @() } }
if (-not $settings['permissions'].Contains('allow')) { $settings['permissions']['allow'] = @() }

$allowSet = [System.Collections.Generic.HashSet[string]]::new()
foreach ($a in $settings['permissions']['allow']) { [void]$allowSet.Add($a) }
foreach ($a in $kitAllows) { [void]$allowSet.Add($a) }
$settings['permissions']['allow'] = @($allowSet) | Sort-Object

# Write back
$settings | ConvertTo-Json -Depth 20 | Set-Content -Path $settingsPath -Encoding UTF8
Write-Ok "settings.json merged ($($settings['permissions']['allow'].Count) allow entries)"

# ============================================================================
# 5. Windows Terminal — set font to JetBrainsMono Nerd Font
# ============================================================================
if (-not $SkipWindowsTerminal) {
    Write-Section "5. Windows Terminal font"

    $wtPaths = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
    )
    $wtPath = $wtPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $wtPath) {
        Write-Warn "Windows Terminal not detected — skipping. Set font manually to 'JetBrainsMono Nerd Font' in your terminal."
    } else {
        Backup-File $wtPath
        try {
            $wt = Get-Content $wtPath -Raw | ConvertFrom-Json -AsHashtable
            if (-not $wt.Contains('profiles')) { $wt['profiles'] = [ordered]@{} }
            if (-not $wt['profiles'].Contains('defaults')) { $wt['profiles']['defaults'] = [ordered]@{} }
            if (-not $wt['profiles']['defaults'].Contains('font')) {
                $wt['profiles']['defaults']['font'] = [ordered]@{ face = 'JetBrainsMono Nerd Font' }
            } else {
                $wt['profiles']['defaults']['font']['face'] = 'JetBrainsMono Nerd Font'
            }
            $wt | ConvertTo-Json -Depth 30 | Set-Content -Path $wtPath -Encoding UTF8
            Write-Ok "Font set to 'JetBrainsMono Nerd Font' in $wtPath"
        } catch {
            Write-Warn "Could not modify Windows Terminal settings: $_"
        }
    }
} else {
    Write-Section "5. Windows Terminal font"
    Write-Info "Skipped (-SkipWindowsTerminal)"
}

# ============================================================================
# 6. MCP server (sequential-thinking)
# ============================================================================
if (-not $SkipMCP) {
    Write-Section "6. MCP server: sequential-thinking"
    if (-not $nodeCmd) {
        Write-Warn "Node.js not found — skipping MCP setup"
    } else {
        $current = & claude mcp list 2>&1
        if ($current -match 'sequential-thinking') {
            Write-Ok "Already configured"
        } else {
            try {
                & claude mcp add sequential-thinking --scope user -- npx -y '@modelcontextprotocol/server-sequential-thinking' 2>&1 | Out-Null
                Write-Ok "Added (will install on first use)"
            } catch {
                Write-Warn "Failed: $_"
            }
        }
    }
} else {
    Write-Section "6. MCP server"
    Write-Info "Skipped (-SkipMCP)"
}

# ============================================================================
# 7. DevRadar (optional — powers Line 3 LOC widget)
# ============================================================================
if (-not $SkipDevRadar) {
    Write-Section "7. DevRadar (optional — Line 3 LOC widget)"
    $devradarCmd = Get-Command devradar -ErrorAction SilentlyContinue
    if ($devradarCmd) {
        Write-Ok "Already installed: $($devradarCmd.Source)"
    } elseif (-not $nodeCmd) {
        Write-Warn "npm not available — skipping. Install Node.js then run: npm install -g devradar"
    } else {
        Write-Info "DevRadar is a code analyzer (LOC, languages, frameworks)."
        Write-Info "Powers Line 3 of the statusLine. Repo: https://github.com/hasoftware/DevRadar"
        if (Confirm-Action "Install DevRadar globally via npm now?") {
            try {
                & npm install -g devradar 2>&1 | ForEach-Object { Write-Info $_ }
                if ($LASTEXITCODE -eq 0) {
                    Write-Ok "DevRadar installed — Line 3 will show after next message"
                } else {
                    Write-Warn "npm returned $LASTEXITCODE — install manually: npm install -g devradar"
                }
            } catch {
                Write-Warn "Failed: $_"
            }
        } else {
            Write-Info "Skipped. To enable Line 3 later, run: npm install -g devradar"
        }
    }
} else {
    Write-Section "7. DevRadar"
    Write-Info "Skipped (-SkipDevRadar)"
}

# ============================================================================
# 8. Done
# ============================================================================
Write-Section "Install complete!"
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor Cyan
Write-Host "    1. Close ALL Windows Terminal windows (to reload font)"
Write-Host "    2. Reopen Windows Terminal"
Write-Host "    3. cd into any project directory and run 'claude'"
Write-Host ""
Write-Host "  Backups (if any) saved next to originals with .backup-<timestamp>" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Files installed in $claudeDir :" -ForegroundColor Cyan
Get-ChildItem $claudeDir -Filter '*.ps1','settings.json' -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -in @('statusline-command.ps1','notify-stop.ps1','set-title.ps1','settings.json') } |
    ForEach-Object { Write-Host "    - $($_.Name)" -ForegroundColor DarkGray }
Write-Host ""
Write-Host "  To revert any file, copy its .backup-<ts> back over the original." -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Stay in touch:" -ForegroundColor Cyan
Write-Host "    Telegram   : https://t.me/hasoftware" -ForegroundColor DarkGray
Write-Host "    Repository : https://github.com/hasoftware/Claudefy" -ForegroundColor DarkGray
Write-Host ""
