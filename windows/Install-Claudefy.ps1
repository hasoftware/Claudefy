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
    Don't prompt to install DevRadar (Line 3 LOC widget will stay disabled until installed manually with `npm install -g @hasoftware/devradar`).

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
$script:TOTAL_STEPS = 7
$script:CURRENT_STEP = 0
$script:START_TIME = Get-Date
$script:WARNINGS = @()

$script:spinPs = $null
$script:spinRs = $null

function Start-Spin([string]$msg) {
    $script:spinLabel = $msg
    $script:spinRs = [runspacefactory]::CreateRunspace()
    $script:spinRs.Open()
    $script:spinPs = [powershell]::Create()
    $script:spinPs.Runspace = $script:spinRs
    [void]$script:spinPs.AddScript({
        param([string]$label)
        $f = [char[]]@(0x280B,0x2819,0x2839,0x2838,0x283C,0x2834,0x2826,0x2827,0x2807,0x280F)
        $i = 0
        try { [Console]::CursorVisible = $false } catch {}
        try {
            while ($true) {
                [Console]::Write("`r  {0} {1}   " -f $f[$i % 10], $label)
                [System.Threading.Thread]::Sleep(80)
                $i++
            }
        } catch {}
    }).AddArgument($msg)
    $script:spinHandle = $script:spinPs.BeginInvoke()
}

function Stop-Spin([string]$result, [bool]$ok = $true) {
    if ($script:spinPs) {
        try {
            $script:spinPs.Stop()
            $script:spinPs.Dispose()
            $script:spinRs.Close()
            $script:spinRs.Dispose()
        } catch {}
        $script:spinPs = $null
        $script:spinRs = $null
    }
    try { [Console]::CursorVisible = $true } catch {}
    [System.Threading.Thread]::Sleep(50)
    $e = [char]27
    [Console]::Write("$e[2K`r")
    if ($ok) {
        Write-Host "  $e[32m$([char]0x2713)$e[0m $result"
    } else {
        Write-Host "  $e[33m!$e[0m $result"
    }
}

function Stop-SpinWarn([string]$result) { Stop-Spin $result $false }

function Write-Detail([string]$msg) { Write-Host "      $msg" -ForegroundColor DarkGray }

function Write-Err([string]$msg) {
    if ($script:spinPs) { Stop-Spin $msg $false }
    else { Write-Host "  $([char]0x2717) $msg" -ForegroundColor Red }
}

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
    }
}

# ============================================================================
# Welcome
# ============================================================================
Write-Host ""
Write-Host "  $([char]0x2588)$([char]0x2588) " -NoNewline -ForegroundColor Cyan
Write-Host "Claudefy" -NoNewline -ForegroundColor White
Write-Host " - make Claude Code yours." -ForegroundColor DarkGray
Write-Host "     https://github.com/hasoftware/Claudefy" -ForegroundColor DarkGray
Write-Host ""
Write-Host "     Components to install:" -ForegroundColor DarkGray
Write-Host "     $([char]0x25C6) Statusline  $([char]0x25C6) Hooks  $([char]0x25C6) Font  $([char]0x25C6) MCP  $([char]0x25C6) DevRadar" -ForegroundColor DarkCyan
Write-Host ""

if (-not (Confirm-Action "  Proceed?")) {
    Write-Host "  Cancelled." -ForegroundColor Yellow
    exit 0
}

# ============================================================================
# 1. Pre-flight checks
# ============================================================================
Start-Spin "Checking requirements..."

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Stop-Spin "PowerShell 7+ required. Install: winget install Microsoft.PowerShell" $false
    exit 1
}

$claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
if (-not $claudeCmd) {
    Stop-Spin "Claude Code CLI not found. Install from https://claude.com/claude-code" $false
    exit 1
}

$gitCmd  = Get-Command git  -ErrorAction SilentlyContinue
$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
$ghCmd   = Get-Command gh   -ErrorAction SilentlyContinue
$wingetCmd = Get-Command winget -ErrorAction SilentlyContinue

$warnings = @()
if (-not $gitCmd)  { $warnings += "git not found" }
if (-not $nodeCmd) { $warnings += "node not found" }
if (-not $ghCmd)   { $warnings += "gh not found" }

$claudeDir = Join-Path $env:USERPROFILE '.claude'
if (-not (Test-Path $claudeDir)) { New-Item -ItemType Directory -Path $claudeDir | Out-Null }

$tools = @("pwsh $($PSVersionTable.PSVersion)", "claude")
if ($gitCmd)  { $tools += "git" }
if ($nodeCmd) { $tools += "node" }
if ($ghCmd)   { $tools += "gh" }
Stop-Spin "Pre-flight — $($tools -join ', ')"
if ($warnings.Count -gt 0) {
    foreach ($w in $warnings) { Write-Detail "  ! $w" }
}

# ============================================================================
# 2. Install JetBrainsMono Nerd Font
# ============================================================================
Start-Spin "Installing Nerd Font..."
if ($SkipFont) {
    Stop-Spin "Nerd Font — skipped" $false
} else {
    $hasNerdFont = $false
    try {
        $shellApp = New-Object -ComObject Shell.Application
        $fontsFolder = $shellApp.NameSpace(0x14)
        $fonts = @($fontsFolder.Items() | ForEach-Object { $_.Name })
        $hasNerdFont = ($fonts | Where-Object { $_ -match 'JetBrainsMono.*Nerd' }).Count -gt 0
    } catch {}

    if ($hasNerdFont) {
        Stop-Spin "Nerd Font — already installed"
    } elseif ($wingetCmd) {
        Stop-Spin "Nerd Font — installing via winget..." $true
        & winget install DEVCOM.JetBrainsMonoNerdFont --silent --accept-source-agreements --accept-package-agreements | Out-Null
        if ($LASTEXITCODE -ne 0) { Write-Detail "  ! winget returned $LASTEXITCODE" }
    } else {
        Stop-Spin "Nerd Font — winget not available, install manually" $false
    }
}

# ============================================================================
# 3. Write helper scripts (statusline, notify-stop, set-title)
# ============================================================================
Start-Spin "Writing helper scripts..."

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
$NF_BATT     = [char]0xF240
$NF_DOCKER   = [char]0xF308
$NF_GLOBE    = [char]0xF0AC
$NF_SEARCH   = [char]0xF002
$NF_MOON     = [char]0xF186
$NF_TROPHY   = [char]0xF091
$NF_BOMB     = [char]0xF1E2

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
    # Widget: editing directly on main/master -> red alert
    if (($branch -eq 'main' -or $branch -eq 'master') -and $dirty -gt 0) { $gbg = 88 }
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

# Widget: battery (laptops — shown when discharging or low; cached 60s)
$btCF = "$env:TEMP\claudefy-batt.txt"
$btRefresh = $true
if (Test-Path $btCF) {
  $btAge = (Get-Date).ToUniversalTime() - (Get-Item $btCF).LastWriteTimeUtc
  if ($btAge.TotalSeconds -lt 60) { $btRefresh = $false }
}
if ($btRefresh) {
  $bLine = ''
  try {
    $batt = Get-CimInstance Win32_Battery -ErrorAction Stop | Select-Object -First 1
    if ($batt) { $bLine = "$([int]$batt.EstimatedChargeRemaining) $($batt.BatteryStatus)" }
  } catch {}
  Set-Content $btCF -Value $bLine -Encoding UTF8
}
$bRaw = ''
try { $bRaw = ((Get-Content $btCF -Raw).Trim()) } catch {}
if ($bRaw) {
  $bParts = $bRaw -split '\s+'
  $bPct = [int]$bParts[0]
  $bStat = if ($bParts.Count -gt 1) { $bParts[1] } else { '' }
  if ($bStat -eq '1' -or $bPct -le 30) {
    $bb = 240
    if ($bPct -le 50) { $bb = 130 }
    if ($bPct -le 20) { $bb = 88 }
    $line1 += @{ bg = $bb; fg = 15; text = " $NF_BATT $bPct% " }
  }
}

# Widget: running Docker containers (cached 60s)
if (Get-Command docker -ErrorAction SilentlyContinue) {
  $dkCF = "$env:TEMP\claudefy-docker.txt"
  $dkRefresh = $true
  if (Test-Path $dkCF) {
    $dkAge = (Get-Date).ToUniversalTime() - (Get-Item $dkCF).LastWriteTimeUtc
    if ($dkAge.TotalSeconds -lt 60) { $dkRefresh = $false }
  }
  if ($dkRefresh) {
    $dkNew = (& docker ps -q 2>$null | Measure-Object).Count
    Set-Content $dkCF -Value $dkNew -Encoding UTF8
  }
  $dkN = 0
  try { $dkN = [int](Get-Content $dkCF -Raw).Trim() } catch {}
  if ($dkN -gt 0) { $line1 += @{ bg = 25; fg = 15; text = " $NF_DOCKER $dkN " } }
}

# Widget: dev server alive on a common port (quick TCP probe)
$srvPort = $null
foreach ($p in 3000, 5173, 8080, 4200, 8000) {
  $tc = New-Object System.Net.Sockets.TcpClient
  try {
    $iar = $tc.BeginConnect('127.0.0.1', $p, $null, $null)
    if ($iar.AsyncWaitHandle.WaitOne(120) -and $tc.Connected) { $srvPort = $p }
  } catch {}
  $tc.Close()
  if ($srvPort) { break }
}
if ($srvPort) { $line1 += @{ bg = 29; fg = 15; text = " $NF_GLOBE :$srvPort " } }

# Widget: permission mode — safety cue
$perm = $d.permission_mode
if (-not $perm) { $perm = $d.permissionMode }
if ($perm -eq 'bypassPermissions') { $line1 += @{ bg = 88;  fg = 15; text = " $([char]0x26A0) YOLO " } }
elseif ($perm -eq 'plan')          { $line1 += @{ bg = 61;  fg = 15; text = " $NF_PEN Plan " } }
elseif ($perm -eq 'acceptEdits')   { $line1 += @{ bg = 130; fg = 0;  text = " $NF_PEN AutoEdit " } }

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
$CLAUDEFY_VER = '1.4.3'
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
  $fhReset = $d.rate_limits.five_hour.resets_at
  if ($null -ne $fhReset) {
    try {
      $nowUnix = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
      $remS = [long]$fhReset - $nowUnix
      if ($remS -gt 0 -and $remS -le 18000) {
        # Widget: quota pace — burning faster than the 5h window elapses
        $elapsedPct = (18000 - $remS) * 100 / 18000
        if ([double]$fh -gt ($elapsedPct + 15)) {
          if ($bg -eq 22) { $bg = 130 }
          $txt += [char]0x2191
        }
        # Widget: countdown to reset once quota is high
        if ([double]$fh -ge 70) { $txt += " (-$([math]::Floor($remS / 60))m)" }
      }
    } catch {}
  }
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

# Smart Model Hint — suggest switching to Sonnet when Opus quota is high
$opHint = $null
if ($null -ne $op) {
  $opHint = [double]$op
} elseif ($d.model.id -and "$($d.model.id)" -match 'opus') {
  if ($null -ne $sd) { $opHint = [double]$sd }
}
if ($null -ne $opHint) {
  if ($opHint -ge 80) {
    $line2 += @{ bg = 88; fg = 15; text = " $([char]0x2192)Sonnet! " }
  } elseif ($opHint -ge 60) {
    $line2 += @{ bg = 58; fg = 15; text = " $([char]0x2192)Sonnet? " }
  }
}

$cost = $d.cost.total_cost_usd
if ($null -ne $cost) {
  $cstr = "{0:N2}" -f [double]$cost
  $ctxt = " $NF_USD `$$cstr"
  # Widget: burn rate $/h (needs >5 min of session for a stable number)
  if ($null -ne $durMs -and [double]$durMs -gt 300000 -and [double]$cost -gt 0) {
    $rate = "{0:N1}" -f ([double]$cost * 3600000 / [double]$durMs)
    $ctxt += " (`$$rate/h)"
  }
  $line2 += @{ bg = 94; fg = 15; text = "$ctxt " }
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

# Turns (from transcript) + session widgets that need the transcript
$tp = $d.transcript_path
if ($tp -and (Test-Path $tp)) {
  $turns = (Select-String -Path $tp -Pattern '"type":"user"' -SimpleMatch | Measure-Object).Count
  if ($turns -gt 0) {
    $ttxt = " $([char]0xF075) $turns turns"
    # Widget: session velocity (turns/hour, needs >10 min)
    if ($null -ne $durMs -and [double]$durMs -gt 600000) {
      $ttxt += " ($([math]::Floor($turns * 3600000 / [double]$durMs))/h)"
    }
    $line2 += @{ bg = 24; fg = 15; text = "$ttxt " }

    # Widget: auto-compact forecast — per-session context burn rate.
    # First render stores (turns, ctx); later renders extrapolate to ~10% left.
    $sessionId = $d.session_id
    if ($null -ne $ctx -and $sessionId) {
      $fcCF = "$env:TEMP\claudefy-ctx-$sessionId.txt"
      $ctxInt = [math]::Floor([double]$ctx)
      if (-not (Test-Path $fcCF)) {
        Set-Content $fcCF -Value "$turns $ctxInt" -Encoding UTF8
      } else {
        try {
          $fcParts = (Get-Content $fcCF -Raw).Trim() -split '\s+'
          $fcDt = $turns - [int]$fcParts[0]
          $fcDc = [int]$fcParts[1] - $ctxInt
          if ($fcDt -ge 3 -and $fcDc -gt 0 -and $ctxInt -le 60) {
            $fcLeft = [math]::Floor(($ctxInt - 10) * $fcDt / $fcDc)
            if ($fcLeft -ge 0 -and $fcLeft -le 30) {
              $fb = if ($fcLeft -le 5) { 88 } else { 130 }
              $line2 += @{ bg = $fb; fg = 15; text = " $([char]0x231B) ~$fcLeft turns$([char]0x2192)compact " }
            }
          }
        } catch {}
      }
    }
  }

  # Widget: session phase — exploring vs building, from recent tool calls
  try {
    $recent = (Get-Content $tp -Tail 300 -ErrorAction SilentlyContinue) -join ' '
    $buildN   = ([regex]::Matches($recent, '"name":"(Edit|Write|NotebookEdit)"')).Count
    $exploreN = ([regex]::Matches($recent, '"name":"(Read|Grep|Glob)"')).Count
    if (($buildN + $exploreN) -ge 5) {
      if ($buildN -ge $exploreN) { $line2 += @{ bg = 22; fg = 15; text = " $NF_PEN build " } }
      else                       { $line2 += @{ bg = 24; fg = 15; text = " $NF_SEARCH explore " } }
    }
  } catch {}

  # Widget: compact count — how many times this session lost its memory
  $cpt = (Select-String -Path $tp -Pattern 'compact_boundary' -SimpleMatch | Measure-Object).Count
  if ($cpt -gt 0) { $line2 += @{ bg = 58; fg = 15; text = " $([char]0x267B) ${cpt}x " } }

  # Widget: idle time since the transcript was last written
  try {
    $idleS = ((Get-Date).ToUniversalTime() - (Get-Item $tp).LastWriteTimeUtc).TotalSeconds
    if ($idleS -ge 600) { $line2 += @{ bg = 240; fg = 15; text = " $NF_MOON idle $([math]::Floor($idleS/60))m " } }
  } catch {}
}

# === LINE 3: Project DNA (DevRadar — cached by git HEAD, TTL 10min) ======
$line3 = @()

# --- Git health widgets: uncommitted pile, branch age, conflict radar ------
if ($branch) {
  # Widget: big uncommitted pile — AI writes fast, commit before you drown
  if ($dirty -gt 0) {
    $ucl = 0
    $nums = @(& git -C $cwd diff --numstat 2>$null) + @(& git -C $cwd diff --cached --numstat 2>$null)
    foreach ($ln in $nums) {
      $pp = "$ln" -split '\s+'
      if ($pp.Count -ge 2) {
        $x = 0; $y = 0
        [void][int]::TryParse($pp[0], [ref]$x)
        [void][int]::TryParse($pp[1], [ref]$y)
        $ucl += $x + $y
      }
    }
    if ($ucl -ge 300) {
      $ub = if ($ucl -ge 800) { 88 } else { 130 }
      $line3 += @{ bg = $ub; fg = 15; text = " $([char]0x26A0) $ucl uncommitted " }
    }
  }

  # Branch age vs main + conflict radar (cached 5 min per cwd|branch)
  $mainRef = $null
  if ($branch -ne 'main' -and $branch -ne 'master') {
    & git -C $cwd show-ref --verify --quiet refs/heads/main 2>$null
    if ($LASTEXITCODE -eq 0) { $mainRef = 'main' }
    else {
      & git -C $cwd show-ref --verify --quiet refs/heads/master 2>$null
      if ($LASTEXITCODE -eq 0) { $mainRef = 'master' }
    }
  }
  if ($mainRef) {
    $ghCK = ($cwd + '|' + $branch) -replace '[\\/:*?"<>|]','_'
    $ghCF = "$env:TEMP\claudefy-githealth-$ghCK.txt"
    $ghRefresh = $true
    if (Test-Path $ghCF) {
      $ghAge = (Get-Date).ToUniversalTime() - (Get-Item $ghCF).LastWriteTimeUtc
      if ($ghAge.TotalSeconds -lt 300) { $ghRefresh = $false }
    }
    if ($ghRefresh) {
      $bAge = 0; $bBehind = 0; $bConf = 0
      $base = & git -C $cwd merge-base HEAD $mainRef 2>$null
      if ($base) {
        $baseTs = & git -C $cwd show -s --format=%ct $base 2>$null
        if ($baseTs) { $bAge = [math]::Floor(([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - [long]$baseTs) / 86400) }
        $bBehind = [int](& git -C $cwd rev-list --count "HEAD..$mainRef" 2>$null)
        # Conflict radar: merge-tree exits 1 iff the merge would conflict (git >= 2.38)
        & git -C $cwd merge-tree --write-tree HEAD $mainRef 2>$null | Out-Null
        if ($LASTEXITCODE -eq 1) { $bConf = 1 }
      }
      Set-Content $ghCF -Value "$bAge $bBehind $bConf" -Encoding UTF8
    }
    try {
      $ghp = (Get-Content $ghCF -Raw).Trim() -split '\s+'
      if ([int]$ghp[0] -ge 3 -or [int]$ghp[1] -ge 10) {
        $line3 += @{ bg = 64; fg = 15; text = " $NF_GIT $($ghp[0])d $([char]0x2193)$($ghp[1]) " }
      }
      if ($ghp[2] -eq '1') { $line3 += @{ bg = 88; fg = 15; text = " $NF_BOMB merge conflicts " } }
    } catch {}
  }
}
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
    $fwList = $null
    if ($devradar.technologies.frameworks -and $devradar.technologies.frameworks.Count -gt 0) {
      $fwList = ($devradar.technologies.frameworks -join [char]0x00B7)
    } elseif ($devradar.byLanguage -and $devradar.byLanguage.Count -gt 0) {
      # No framework detected -> fall back to the dominant language
      $fwList = $devradar.byLanguage[0].language
    }
    if ($fwList) { $line3 += @{ bg = 60; fg = 15; text = " $NF_CUBE $fwList " } }

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

# === LINE 4: Branding + daily widgets ======================================
$line4 = @()

$projDir = Join-Path $env:USERPROFILE '.claude\projects'
if (Test-Path $projDir) {
  # Widget: total output tokens across ALL sessions today (cached 5 min).
  # (Transcripts no longer carry per-message cost, so tokens are the honest sum.)
  $ctCF = "$env:TEMP\claudefy-tokens-today.txt"
  $ctRefresh = $true
  if (Test-Path $ctCF) {
    $ctAge = (Get-Date).ToUniversalTime() - (Get-Item $ctCF).LastWriteTimeUtc
    if ($ctAge.TotalSeconds -lt 300) { $ctRefresh = $false }
  }
  if ($ctRefresh) {
    $ctNew = 0L
    $midnight = (Get-Date).Date
    Get-ChildItem $projDir -Recurse -Filter '*.jsonl' -ErrorAction SilentlyContinue |
      Where-Object { $_.LastWriteTime -ge $midnight } | ForEach-Object {
        Select-String -Path $_.FullName -Pattern '"output_tokens":(\d+)' -AllMatches -ErrorAction SilentlyContinue |
          ForEach-Object { $_.Matches } | ForEach-Object { $ctNew += [long]$_.Groups[1].Value }
      }
    Set-Content $ctCF -Value $ctNew -Encoding UTF8
  }
  $ctSum = 0L
  try { $ctSum = [long](Get-Content $ctCF -Raw).Trim() } catch {}
  if ($ctSum -gt 0) {
    $ctHuman = if ($ctSum -ge 1e6) { "{0:N1}M" -f ($ctSum/1e6) }
               elseif ($ctSum -ge 1e3) { "{0:N1}k" -f ($ctSum/1e3) }
               else { "$ctSum" }
    $line4 += @{ bg = 94; fg = 15; text = " $([char]0x03A3) $ctHuman out today " }
  }

  # Widget: usage streak — consecutive days with Claude Code activity (cached 1h)
  $stCF = "$env:TEMP\claudefy-streak.txt"
  $stRefresh = $true
  if (Test-Path $stCF) {
    $stAge = (Get-Date).ToUniversalTime() - (Get-Item $stCF).LastWriteTimeUtc
    if ($stAge.TotalSeconds -lt 3600) { $stRefresh = $false }
  }
  if ($stRefresh) {
    $stDates = Get-ChildItem $projDir -Recurse -Filter '*.jsonl' -ErrorAction SilentlyContinue |
      Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-40) } |
      ForEach-Object { $_.LastWriteTime.ToString('yyyy-MM-dd') } | Sort-Object -Unique
    $stNew = 0; $stI = 0
    while ($stI -lt 40) {
      $dd = (Get-Date).AddDays(-$stI).ToString('yyyy-MM-dd')
      if ($stDates -contains $dd) { $stNew++; $stI++ }
      elseif ($stI -eq 0) { $stI = 1 }   # today may have no finished write yet
      else { break }
    }
    Set-Content $stCF -Value $stNew -Encoding UTF8
  }
  $streak = 0
  try { $streak = [int](Get-Content $stCF -Raw).Trim() } catch {}
  if ($streak -ge 2) { $line4 += @{ bg = 58; fg = 15; text = " $NF_TROPHY ${streak}d streak " } }
}

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

# Save session stats
$statsFile = Join-Path $env:USERPROFILE '.claude\claudefy-stats.jsonl'
try {
  $project = if ($d.workspace.current_dir) { Split-Path -Leaf $d.workspace.current_dir }
             elseif ($d.cwd) { Split-Path -Leaf $d.cwd }
             else { 'unknown' }
  $tp = $d.transcript_path
  $turns = 0
  if ($tp -and (Test-Path $tp)) {
    $turns = (Select-String -Path $tp -Pattern '"type":"user"' -SimpleMatch | Measure-Object).Count
  }
  $stat = [ordered]@{
    ts       = (Get-Date).ToUniversalTime().ToString('o')
    sid      = $d.session_id
    project  = $project
    model    = if ($d.model.id) { $d.model.id } elseif ($d.model) { "$($d.model)" } else { 'unknown' }
    cost     = if ($null -ne $d.cost.total_cost_usd) { [math]::Round([double]$d.cost.total_cost_usd, 4) } else { 0 }
    dur_ms   = if ($null -ne $d.cost.total_duration_ms) { [long]$d.cost.total_duration_ms } else { 0 }
    lines_add = if ($null -ne $d.cost.total_lines_added) { [int]$d.cost.total_lines_added } else { 0 }
    lines_rm  = if ($null -ne $d.cost.total_lines_removed) { [int]$d.cost.total_lines_removed } else { 0 }
    tok_in   = if ($null -ne $d.context_window.total_input_tokens) { [long]$d.context_window.total_input_tokens } else { 0 }
    tok_out  = if ($null -ne $d.context_window.total_output_tokens) { [long]$d.context_window.total_output_tokens } else { 0 }
    turns    = $turns
  }
  $stat | ConvertTo-Json -Compress | Add-Content -Path $statsFile -Encoding UTF8
} catch {}

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
Stop-Spin "Helper scripts — 3 files written"

# ============================================================================
# 4. Merge Claude Code settings.json
# ============================================================================
Start-Spin "Merging settings..."

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
    } catch { }
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
$allowCount = $settings['permissions']['allow'].Count
Stop-Spin "Settings merged — $allowCount allow entries"

# ============================================================================
# 5. Windows Terminal — set font to JetBrainsMono Nerd Font
# ============================================================================
Start-Spin "Configuring Windows Terminal..."
if ($SkipWindowsTerminal) {
    Stop-Spin "Windows Terminal — skipped" $false
} else {
    $wtPaths = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
    )
    $wtPath = $wtPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $wtPath) {
        Stop-Spin "Windows Terminal — not detected, set font manually" $false
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
            Stop-Spin "Windows Terminal — font configured"
        } catch {
            Stop-Spin "Windows Terminal — failed: $_" $false
        }
    }
}

# ============================================================================
# 6. MCP server (sequential-thinking)
# ============================================================================
Start-Spin "Setting up MCP server..."
if ($SkipMCP) {
    Stop-Spin "MCP server — skipped" $false
} elseif (-not $nodeCmd) {
    Stop-Spin "MCP server — node not found, skipping" $false
} else {
    $current = & claude mcp list 2>&1
    if ($current -match 'sequential-thinking') {
        Stop-Spin "MCP server — already configured"
    } else {
        try {
            & claude mcp add sequential-thinking --scope user -- npx -y '@modelcontextprotocol/server-sequential-thinking' 2>&1 | Out-Null
            Stop-Spin "MCP server — sequential-thinking added"
        } catch {
            Stop-Spin "MCP server — failed: $_" $false
        }
    }
}

# ============================================================================
# 7. DevRadar (optional — powers Line 3 LOC widget)
# ============================================================================
if ($SkipDevRadar) {
    Start-Spin "DevRadar..."
    Stop-Spin "DevRadar — skipped" $false
} else {
    $devradarCmd = Get-Command devradar -ErrorAction SilentlyContinue
    if ($devradarCmd) {
        Start-Spin "DevRadar..."
        Stop-Spin "DevRadar — already installed"
    } elseif (-not $nodeCmd) {
        Start-Spin "DevRadar..."
        Stop-Spin "DevRadar — npm not available" $false
    } else {
        Write-Host ""
        Write-Host "  ? " -NoNewline -ForegroundColor Cyan
        Write-Host "DevRadar powers Line 3 (LOC, frameworks). Install globally?" -ForegroundColor White
        if (Confirm-Action "   ") {
            Start-Spin "Installing DevRadar..."
            & npm install -g @hasoftware/devradar 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Stop-Spin "DevRadar — installed"
            } else {
                Stop-Spin "DevRadar — npm failed, install manually" $false
            }
        } else {
            Start-Spin "DevRadar..."
            Stop-Spin "DevRadar — skipped (install later: npm i -g devradar)" $false
        }
    }
}

# ============================================================================
# 8. Done
# ============================================================================
$elapsed = ((Get-Date) - $script:START_TIME).TotalSeconds
$elapsed = [math]::Round($elapsed, 1)

Write-Host ""
Write-Host ("  " + [string][char]0x2501 * 45) -ForegroundColor DarkCyan
Write-Host ""
Write-Host "  $([char]0x2705) " -NoNewline
Write-Host "All $script:TOTAL_STEPS steps completed" -NoNewline -ForegroundColor Green
Write-Host " in ${elapsed}s" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  $([char]0x2192) " -NoNewline -ForegroundColor Cyan
Write-Host "Close & reopen terminal, then run " -NoNewline
Write-Host "claude" -ForegroundColor Cyan
Write-Host ""
Write-Host "     Backups saved with .backup-<timestamp> suffix" -ForegroundColor DarkGray
Write-Host "     Telegram: t.me/hasoftware  |  github.com/hasoftware/Claudefy" -ForegroundColor DarkGray
Write-Host ""
