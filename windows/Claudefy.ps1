#Requires -Version 7

<#
.SYNOPSIS
    Claudefy - make Claude Code yours.

.DESCRIPTION
    Interactive menu for managing the Claudefy customization kit:
      1. Install Claudefy (statusLine + hooks + font + MCP + allowlist)
      2. Reset to Default (revert all kit changes)
      3. Theme for Claude Code (pick from 10 curated terminal themes)
      4. About

.NOTES
    Author     : Hoang Anh Dev
    Admin      : HASOFTWARE
    Telegram   : https://t.me/hasoftware
    Repository : https://github.com/hasoftware/Claudefy

.EXAMPLE
    .\Claudefy.ps1
#>

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding           = [System.Text.UTF8Encoding]::new($false)

$VERSION    = '1.0.1'
$AUTHOR     = 'Hoang Anh Dev'
$ADMIN      = 'HASOFTWARE'
$TELEGRAM   = 'https://t.me/hasoftware'
$REPO       = 'https://github.com/hasoftware/Claudefy'
$claudeDir  = Join-Path $env:USERPROFILE '.claude'
$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$installPs1 = Join-Path $scriptDir 'Install-Claudefy.ps1'

# ============================================================================
# UI helpers
# ============================================================================
function Write-Banner {
    Clear-Host
    $bannerColor = 'Cyan'
    $accentColor = 'Yellow'
    Write-Host ""
    Write-Host "   ____ _                 _       __       " -ForegroundColor $bannerColor
    Write-Host "  / ___| | __ _ _   _  __| | ___ / _|_   _ " -ForegroundColor $bannerColor
    Write-Host " | |   | |/ _``| | | |/ _``|/ _ \ |_| | | |" -ForegroundColor $bannerColor
    Write-Host " | |___| | (_| | |_| | (_| |  __/  _| |_| |" -ForegroundColor $bannerColor
    Write-Host "  \____|_|\__,_|\__,_|\__,_|\___|_|  \__, |" -ForegroundColor $bannerColor
    Write-Host "                                     |___/ " -ForegroundColor $bannerColor
    Write-Host ""
    Write-Host "       Claudefy " -ForegroundColor $accentColor -NoNewline
    Write-Host "v$VERSION  -  " -ForegroundColor DarkGray -NoNewline
    Write-Host "make Claude Code yours." -ForegroundColor White
    Write-Host "       by $AUTHOR" -ForegroundColor DarkGray -NoNewline
    Write-Host "  -  " -ForegroundColor DarkGray -NoNewline
    Write-Host "$ADMIN" -ForegroundColor DarkYellow
    Write-Host ""
}

function Write-Section([string]$title) {
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor DarkCyan
    Write-Host "  $title"  -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor DarkCyan
}

function Pause-Continue {
    Write-Host ""
    Write-Host "Press Enter to return to menu..." -ForegroundColor DarkGray
    [void](Read-Host)
}

function Backup-File([string]$path) {
    if (Test-Path $path) {
        $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
        $backup = "$path.backup-$ts"
        Copy-Item -Path $path -Destination $backup -Force
        Write-Host "  [backup] -> $backup" -ForegroundColor DarkGray
    }
}

function Get-WindowsTerminalSettingsPath {
    $paths = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
    )
    return ($paths | Where-Object { Test-Path $_ } | Select-Object -First 1)
}

# ============================================================================
# 1. Install
# ============================================================================
function Invoke-Install {
    Write-Section "1. Install Claudefy"
    if (-not (Test-Path $installPs1)) {
        Write-Host "  [X] Install-Claudefy.ps1 not found at: $installPs1" -ForegroundColor Red
        Write-Host "      Make sure both scripts are in the same folder." -ForegroundColor Yellow
        Pause-Continue
        return
    }
    Write-Host "  Launching installer..." -ForegroundColor Green
    Write-Host ""
    & $installPs1
    Pause-Continue
}

# ============================================================================
# 2. Reset to default
# ============================================================================
function Invoke-Reset {
    Write-Section "2. Reset to Default"
    Write-Host "  This will:"
    Write-Host "    - Remove kit's statusLine, SessionStart and Stop hooks from settings.json"
    Write-Host "    - Remove kit-added permission allowlist entries"
    Write-Host "    - Delete statusline-command.ps1, notify-stop.ps1, set-title.ps1"
    Write-Host "    - Revert Windows Terminal font + colorScheme to system default"
    Write-Host ""
    Write-Host "  It WILL NOT:" -ForegroundColor DarkGray
    Write-Host "    - Uninstall JetBrainsMono Nerd Font from system"
    Write-Host "    - Remove MCP servers"
    Write-Host "    - Delete your other settings.json fields (language, theme, verbose, ...)"
    Write-Host ""
    $confirm = Read-Host "Proceed? (type RESET to confirm)"
    if ($confirm -ne 'RESET') {
        Write-Host "  Cancelled." -ForegroundColor Yellow
        Pause-Continue
        return
    }

    # --- 1. Clean settings.json -------------------------------------------
    $settingsPath = Join-Path $claudeDir 'settings.json'
    if (Test-Path $settingsPath) {
        Backup-File $settingsPath
        try {
            $s = Get-Content $settingsPath -Raw | ConvertFrom-Json -AsHashtable

            # Remove statusLine if it points to our script
            if ($s.Contains('statusLine') -and $s['statusLine'].command -like '*statusline-command.ps1*') {
                $s.Remove('statusLine')
                Write-Host "  [-] statusLine removed" -ForegroundColor DarkGreen
            }

            # Remove our hooks
            if ($s.Contains('hooks')) {
                foreach ($evt in @('SessionStart','Stop')) {
                    if ($s['hooks'].Contains($evt)) {
                        $filtered = @()
                        foreach ($entry in $s['hooks'][$evt]) {
                            $keep = $true
                            if ($entry.hooks) {
                                foreach ($h in $entry.hooks) {
                                    if ($h.command -like '*notify-stop.ps1*' -or
                                        $h.command -like '*set-title.ps1*') {
                                        $keep = $false; break
                                    }
                                }
                            }
                            if ($keep) { $filtered += $entry }
                        }
                        if ($filtered.Count -eq 0) {
                            $s['hooks'].Remove($evt)
                        } else {
                            $s['hooks'][$evt] = $filtered
                        }
                    }
                }
                if ($s['hooks'].Count -eq 0) { $s.Remove('hooks') }
                Write-Host "  [-] Hooks removed" -ForegroundColor DarkGreen
            }

            # Remove kit-added permission entries (those matching well-known kit patterns)
            $kitPatterns = @(
                'Bash(ls:*)','Bash(pwd)','Bash(cat:*)','Bash(head:*)','Bash(tail:*)',
                'Bash(file:*)','Bash(wc:*)','Bash(echo:*)','Bash(date:*)','Bash(which:*)',
                'Bash(env)','Bash(printenv:*)',
                'Bash(git status:*)','Bash(git log:*)','Bash(git diff:*)',
                'Bash(git branch:*)','Bash(git remote:*)','Bash(git show:*)',
                'Bash(git fetch:*)','Bash(git rev-parse:*)','Bash(git rev-list:*)',
                'Bash(git symbolic-ref:*)','Bash(git config --get:*)',
                'Bash(git stash list:*)','Bash(git tag:*)','Bash(git blame:*)',
                'Bash(git ls-files:*)','Bash(git describe:*)',
                'Bash(node --version)','Bash(npm --version)','Bash(npm ls:*)',
                'Bash(npm run test:*)','Bash(npm test:*)',
                'Bash(python --version)','Bash(python -V)','Bash(pip list:*)','Bash(pip show:*)',
                'Bash(pwsh --version)','Bash(git --version)','Bash(gh --version)',
                'Bash(go version)','Bash(cargo --version)','Bash(rustc --version)',
                'Bash(gh pr list:*)','Bash(gh pr view:*)','Bash(gh pr diff:*)',
                'Bash(gh issue list:*)','Bash(gh issue view:*)',
                'Bash(gh repo view:*)','Bash(gh api repos:*)',
                'PowerShell(Get-Content:*)','PowerShell(Get-ChildItem:*)',
                'PowerShell(Get-Command:*)','PowerShell(Test-Path:*)',
                'PowerShell(Get-Date:*)','PowerShell(Get-Item:*)',
                'PowerShell(Select-Object:*)','PowerShell(Measure-Object:*)',
                'PowerShell(Get-Process:*)','PowerShell(Get-Service:*)'
            )
            if ($s.Contains('permissions') -and $s['permissions'].Contains('allow')) {
                $before = $s['permissions']['allow'].Count
                $kept = @($s['permissions']['allow'] | Where-Object { $_ -notin $kitPatterns })
                $s['permissions']['allow'] = $kept
                $removed = $before - $kept.Count
                Write-Host "  [-] $removed kit allowlist entries removed" -ForegroundColor DarkGreen
            }

            $s | ConvertTo-Json -Depth 20 | Set-Content -Path $settingsPath -Encoding UTF8
            Write-Host "  [OK] settings.json cleaned" -ForegroundColor Green
        } catch {
            Write-Host "  [!] Could not clean settings.json: $_" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  (no settings.json found)" -ForegroundColor DarkGray
    }

    # --- 2. Delete kit ps1 files ------------------------------------------
    foreach ($n in @('statusline-command.ps1','notify-stop.ps1','set-title.ps1')) {
        $p = Join-Path $claudeDir $n
        if (Test-Path $p) {
            Remove-Item $p -Force
            Write-Host "  [-] Deleted $n" -ForegroundColor DarkGreen
        }
    }

    # --- 3. Revert Windows Terminal font + colorScheme --------------------
    $wtPath = Get-WindowsTerminalSettingsPath
    if ($wtPath) {
        Backup-File $wtPath
        try {
            $wt = Get-Content $wtPath -Raw | ConvertFrom-Json -AsHashtable
            $defaults = $wt['profiles']['defaults']
            if ($defaults -and $defaults.Contains('font') -and
                $defaults['font']['face'] -eq 'JetBrainsMono Nerd Font') {
                $defaults.Remove('font')
                Write-Host "  [-] WT font reset" -ForegroundColor DarkGreen
            }
            # Remove any Claude-* color schemes we may have added
            if ($wt.Contains('schemes')) {
                $kept = @($wt['schemes'] | Where-Object { $_.name -notlike 'Claude *' })
                $wt['schemes'] = $kept
            }
            $wt | ConvertTo-Json -Depth 30 | Set-Content -Path $wtPath -Encoding UTF8
            Write-Host "  [OK] Windows Terminal reverted" -ForegroundColor Green
        } catch {
            Write-Host "  [!] Could not modify WT settings: $_" -ForegroundColor Yellow
        }
    }

    Write-Host ""
    Write-Host "  Reset complete. Restart Windows Terminal + Claude Code." -ForegroundColor Cyan
    Pause-Continue
}

# ============================================================================
# 3. Theme for Claude Code (10 curated terminal color schemes)
# ============================================================================
function Get-Themes {
    return @(
        # 1. One Half Dark (Atom inspired)
        [ordered]@{
            name = 'Claude: One Half Dark'
            background = '#282C34'; foreground = '#DCDFE4'
            cursorColor = '#A3BE8C'; selectionBackground = '#4F5666'
            black = '#282C34'; red = '#E06C75'; green = '#98C379'; yellow = '#E5C07B'
            blue = '#61AFEF'; purple = '#C678DD'; cyan = '#56B6C2'; white = '#DCDFE4'
            brightBlack = '#5C6370'; brightRed = '#E06C75'; brightGreen = '#98C379'
            brightYellow = '#E5C07B'; brightBlue = '#61AFEF'; brightPurple = '#C678DD'
            brightCyan = '#56B6C2'; brightWhite = '#FFFFFF'
        }
        # 2. Dracula
        [ordered]@{
            name = 'Claude: Dracula'
            background = '#282A36'; foreground = '#F8F8F2'
            cursorColor = '#FF79C6'; selectionBackground = '#44475A'
            black = '#21222C'; red = '#FF5555'; green = '#50FA7B'; yellow = '#F1FA8C'
            blue = '#BD93F9'; purple = '#FF79C6'; cyan = '#8BE9FD'; white = '#F8F8F2'
            brightBlack = '#6272A4'; brightRed = '#FF6E6E'; brightGreen = '#69FF94'
            brightYellow = '#FFFFA5'; brightBlue = '#D6ACFF'; brightPurple = '#FF92DF'
            brightCyan = '#A4FFFF'; brightWhite = '#FFFFFF'
        }
        # 3. Tokyo Night
        [ordered]@{
            name = 'Claude: Tokyo Night'
            background = '#1A1B26'; foreground = '#C0CAF5'
            cursorColor = '#C0CAF5'; selectionBackground = '#33467C'
            black = '#15161E'; red = '#F7768E'; green = '#9ECE6A'; yellow = '#E0AF68'
            blue = '#7AA2F7'; purple = '#BB9AF7'; cyan = '#7DCFFF'; white = '#A9B1D6'
            brightBlack = '#414868'; brightRed = '#F7768E'; brightGreen = '#9ECE6A'
            brightYellow = '#E0AF68'; brightBlue = '#7AA2F7'; brightPurple = '#BB9AF7'
            brightCyan = '#7DCFFF'; brightWhite = '#C0CAF5'
        }
        # 4. Catppuccin Mocha
        [ordered]@{
            name = 'Claude: Catppuccin Mocha'
            background = '#1E1E2E'; foreground = '#CDD6F4'
            cursorColor = '#F5E0DC'; selectionBackground = '#585B70'
            black = '#45475A'; red = '#F38BA8'; green = '#A6E3A1'; yellow = '#F9E2AF'
            blue = '#89B4FA'; purple = '#F5C2E7'; cyan = '#94E2D5'; white = '#BAC2DE'
            brightBlack = '#585B70'; brightRed = '#F38BA8'; brightGreen = '#A6E3A1'
            brightYellow = '#F9E2AF'; brightBlue = '#89B4FA'; brightPurple = '#F5C2E7'
            brightCyan = '#94E2D5'; brightWhite = '#A6ADC8'
        }
        # 5. Nord
        [ordered]@{
            name = 'Claude: Nord'
            background = '#2E3440'; foreground = '#D8DEE9'
            cursorColor = '#D8DEE9'; selectionBackground = '#4C566A'
            black = '#3B4252'; red = '#BF616A'; green = '#A3BE8C'; yellow = '#EBCB8B'
            blue = '#81A1C1'; purple = '#B48EAD'; cyan = '#88C0D0'; white = '#E5E9F0'
            brightBlack = '#4C566A'; brightRed = '#BF616A'; brightGreen = '#A3BE8C'
            brightYellow = '#EBCB8B'; brightBlue = '#81A1C1'; brightPurple = '#B48EAD'
            brightCyan = '#8FBCBB'; brightWhite = '#ECEFF4'
        }
        # 6. Solarized Dark
        [ordered]@{
            name = 'Claude: Solarized Dark'
            background = '#002B36'; foreground = '#839496'
            cursorColor = '#93A1A1'; selectionBackground = '#073642'
            black = '#073642'; red = '#DC322F'; green = '#859900'; yellow = '#B58900'
            blue = '#268BD2'; purple = '#D33682'; cyan = '#2AA198'; white = '#EEE8D5'
            brightBlack = '#002B36'; brightRed = '#CB4B16'; brightGreen = '#586E75'
            brightYellow = '#657B83'; brightBlue = '#839496'; brightPurple = '#6C71C4'
            brightCyan = '#93A1A1'; brightWhite = '#FDF6E3'
        }
        # 7. Gruvbox Dark
        [ordered]@{
            name = 'Claude: Gruvbox Dark'
            background = '#282828'; foreground = '#EBDBB2'
            cursorColor = '#EBDBB2'; selectionBackground = '#504945'
            black = '#282828'; red = '#CC241D'; green = '#98971A'; yellow = '#D79921'
            blue = '#458588'; purple = '#B16286'; cyan = '#689D6A'; white = '#A89984'
            brightBlack = '#928374'; brightRed = '#FB4934'; brightGreen = '#B8BB26'
            brightYellow = '#FABD2F'; brightBlue = '#83A598'; brightPurple = '#D3869B'
            brightCyan = '#8EC07C'; brightWhite = '#EBDBB2'
        }
        # 8. Monokai Classic
        [ordered]@{
            name = 'Claude: Monokai'
            background = '#272822'; foreground = '#F8F8F2'
            cursorColor = '#F8F8F0'; selectionBackground = '#49483E'
            black = '#272822'; red = '#F92672'; green = '#A6E22E'; yellow = '#F4BF75'
            blue = '#66D9EF'; purple = '#AE81FF'; cyan = '#A1EFE4'; white = '#F8F8F2'
            brightBlack = '#75715E'; brightRed = '#F92672'; brightGreen = '#A6E22E'
            brightYellow = '#F4BF75'; brightBlue = '#66D9EF'; brightPurple = '#AE81FF'
            brightCyan = '#A1EFE4'; brightWhite = '#F9F8F5'
        }
        # 9. Synthwave 84 (retro neon)
        [ordered]@{
            name = "Claude: Synthwave '84"
            background = '#2A2139'; foreground = '#F4EEFF'
            cursorColor = '#FF7EDB'; selectionBackground = '#463465'
            black = '#000000'; red = '#FE4450'; green = '#72F1B8'; yellow = '#FEDE5D'
            blue = '#03EDF9'; purple = '#FF7EDB'; cyan = '#03EDF9'; white = '#F4EEFF'
            brightBlack = '#495495'; brightRed = '#FE4450'; brightGreen = '#72F1B8'
            brightYellow = '#FEDE5D'; brightBlue = '#03EDF9'; brightPurple = '#FF7EDB'
            brightCyan = '#03EDF9'; brightWhite = '#FFFFFF'
        }
        # 10. GitHub Dark
        [ordered]@{
            name = 'Claude: GitHub Dark'
            background = '#0D1117'; foreground = '#C9D1D9'
            cursorColor = '#58A6FF'; selectionBackground = '#264F78'
            black = '#484F58'; red = '#FF7B72'; green = '#3FB950'; yellow = '#D29922'
            blue = '#58A6FF'; purple = '#BC8CFF'; cyan = '#39C5CF'; white = '#B1BAC4'
            brightBlack = '#6E7681'; brightRed = '#FFA198'; brightGreen = '#56D364'
            brightYellow = '#E3B341'; brightBlue = '#79C0FF'; brightPurple = '#D2A8FF'
            brightCyan = '#56D4DD'; brightWhite = '#F0F6FC'
        }
    )
}

function Invoke-ThemePicker {
    Write-Section "3. Theme for Claude Code"

    $wtPath = Get-WindowsTerminalSettingsPath
    if (-not $wtPath) {
        Write-Host "  [X] Windows Terminal not detected." -ForegroundColor Red
        Pause-Continue
        return
    }

    $themes = Get-Themes
    $current = $null
    try {
        $wt = Get-Content $wtPath -Raw | ConvertFrom-Json -AsHashtable
        if ($wt['profiles']['defaults']) { $current = $wt['profiles']['defaults']['colorScheme'] }
    } catch {}

    Write-Host ""
    Write-Host "  Current theme: " -NoNewline -ForegroundColor DarkGray
    Write-Host "$current" -ForegroundColor White
    Write-Host ""
    Write-Host "  Available themes:" -ForegroundColor Cyan
    Write-Host ""
    for ($i = 0; $i -lt $themes.Count; $i++) {
        $t = $themes[$i]
        $marker = if ($t.name -eq $current) { '*' } else { ' ' }
        $num = "  $marker [{0,2}]" -f ($i + 1)
        Write-Host $num -NoNewline -ForegroundColor Cyan
        Write-Host "  $($t.name)" -NoNewline
        $accent = $t.cursorColor
        Write-Host "   bg=" -NoNewline -ForegroundColor DarkGray
        Write-Host "$($t.background)" -NoNewline -ForegroundColor DarkGray
        Write-Host "  accent=" -NoNewline -ForegroundColor DarkGray
        Write-Host "$accent" -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host "   [0]  Revert to system default (remove Claude theme)" -ForegroundColor DarkGray
    Write-Host "   [Q]  Cancel" -ForegroundColor DarkGray
    Write-Host ""
    $choice = Read-Host "  Pick a theme number"

    if ($choice -match '^[Qq]') { return }

    if ($choice -eq '0') {
        Backup-File $wtPath
        try {
            $wt = Get-Content $wtPath -Raw | ConvertFrom-Json -AsHashtable
            if ($wt['profiles']['defaults'] -and $wt['profiles']['defaults'].Contains('colorScheme')) {
                $wt['profiles']['defaults'].Remove('colorScheme')
            }
            if ($wt.Contains('schemes')) {
                $wt['schemes'] = @($wt['schemes'] | Where-Object { $_.name -notlike 'Claude:*' })
            }
            $wt | ConvertTo-Json -Depth 30 | Set-Content -Path $wtPath -Encoding UTF8
            Write-Host "  [OK] Reverted to system default" -ForegroundColor Green
        } catch { Write-Host "  [X] $_" -ForegroundColor Red }
        Pause-Continue
        return
    }

    $idx = 0
    if (-not [int]::TryParse($choice, [ref]$idx) -or $idx -lt 1 -or $idx -gt $themes.Count) {
        Write-Host "  [X] Invalid choice." -ForegroundColor Red
        Pause-Continue
        return
    }
    $picked = $themes[$idx - 1]

    Backup-File $wtPath
    try {
        $wt = Get-Content $wtPath -Raw | ConvertFrom-Json -AsHashtable

        if (-not $wt.Contains('schemes')) { $wt['schemes'] = @() }
        # Remove existing scheme with same name to avoid duplicates
        $wt['schemes'] = @($wt['schemes'] | Where-Object { $_.name -ne $picked.name })
        $wt['schemes'] += $picked

        if (-not $wt['profiles']) { $wt['profiles'] = [ordered]@{} }
        if (-not $wt['profiles']['defaults']) { $wt['profiles']['defaults'] = [ordered]@{} }
        $wt['profiles']['defaults']['colorScheme'] = $picked.name

        $wt | ConvertTo-Json -Depth 30 | Set-Content -Path $wtPath -Encoding UTF8
        Write-Host ""
        Write-Host "  [OK] Theme set to '$($picked.name)'" -ForegroundColor Green
        Write-Host "       Restart Windows Terminal to see changes." -ForegroundColor DarkGray
    } catch {
        Write-Host "  [X] Could not apply theme: $_" -ForegroundColor Red
    }

    Pause-Continue
}

# ============================================================================
# 4. About
# ============================================================================
function Show-About {
    Write-Section "4. About"
    Write-Host ""
    Write-Host "  Claudefy " -NoNewline -ForegroundColor Yellow
    Write-Host "v$VERSION" -ForegroundColor Cyan
    Write-Host "  Make Claude Code yours - customization kit for Windows"
    Write-Host ""
    Write-Host "  Author      : " -NoNewline -ForegroundColor DarkGray; Write-Host $AUTHOR -ForegroundColor White
    Write-Host "  Admin       : " -NoNewline -ForegroundColor DarkGray; Write-Host $ADMIN -ForegroundColor Yellow
    Write-Host "  Telegram    : " -NoNewline -ForegroundColor DarkGray; Write-Host $TELEGRAM -ForegroundColor Cyan
    Write-Host "  Repository  : " -NoNewline -ForegroundColor DarkGray; Write-Host $REPO -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Components installed by this kit:" -ForegroundColor Cyan
    Write-Host ""
    $items = @(
        @{ name = 'statusline-command.ps1'; desc = 'Powerline 2-3 line statusLine (Line 3 needs DevRadar)'; path = (Join-Path $claudeDir 'statusline-command.ps1') }
        @{ name = 'notify-stop.ps1';        desc = 'Stop hook (notification + quota alerts)'; path = (Join-Path $claudeDir 'notify-stop.ps1') }
        @{ name = 'set-title.ps1';          desc = 'SessionStart hook (dynamic tab title)'; path = (Join-Path $claudeDir 'set-title.ps1') }
        @{ name = 'settings.json';          desc = 'Claude Code config'; path = (Join-Path $claudeDir 'settings.json') }
    )
    foreach ($i in $items) {
        $status = if (Test-Path $i.path) { '[OK]' } else { '[--]' }
        $color  = if (Test-Path $i.path) { 'Green' } else { 'DarkGray' }
        Write-Host "  $status " -NoNewline -ForegroundColor $color
        Write-Host "$($i.name)" -NoNewline
        Write-Host "  - $($i.desc)" -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host "  Environment:" -ForegroundColor Cyan
    Write-Host "    PowerShell: $($PSVersionTable.PSVersion)"
    Write-Host "    User dir:   $claudeDir"
    $claudeVer = & claude --version 2>$null
    if ($claudeVer) { Write-Host "    Claude:     $claudeVer" }
    $nf = $false
    try {
        $shellApp = New-Object -ComObject Shell.Application
        $fonts = @($shellApp.NameSpace(0x14).Items() | ForEach-Object { $_.Name })
        $nf = ($fonts | Where-Object { $_ -match 'JetBrainsMono.*Nerd' }).Count -gt 0
    } catch {}
    Write-Host "    Nerd Font:  $(if ($nf) { 'JetBrainsMono Nerd Font installed' } else { 'not detected' })"
    Write-Host ""
    Write-Host "  Hotkeys in Claude Code:" -ForegroundColor Cyan
    Write-Host "    /usage   - show quota details"
    Write-Host "    /exit    - close session"
    Write-Host "    Ctrl+C   - cancel current generation"
    Write-Host ""
    Pause-Continue
}

# ============================================================================
# Main menu loop
# ============================================================================
function Show-MainMenu {
    while ($true) {
        Write-Banner

        Write-Host "  Main Menu" -ForegroundColor Cyan
        Write-Host ("  " + ("-" * 30)) -ForegroundColor DarkCyan
        Write-Host "    [1] " -NoNewline -ForegroundColor Cyan; Write-Host "Install Claudefy"
        Write-Host "    [2] " -NoNewline -ForegroundColor Cyan; Write-Host "Reset to Default"
        Write-Host "    [3] " -NoNewline -ForegroundColor Cyan; Write-Host "Theme for Claude Code"
        Write-Host "    [4] " -NoNewline -ForegroundColor Cyan; Write-Host "About"
        Write-Host ""
        Write-Host "    [Q] " -NoNewline -ForegroundColor DarkGray; Write-Host "Quit" -ForegroundColor DarkGray
        Write-Host ""
        $choice = Read-Host "  Choose an option"

        switch -Regex ($choice) {
            '^1$' { Invoke-Install }
            '^2$' { Invoke-Reset }
            '^3$' { Invoke-ThemePicker }
            '^4$' { Show-About }
            '^[Qq]$' { Write-Host "`n  Goodbye!`n" -ForegroundColor Cyan; return }
            default { Write-Host "  Invalid choice." -ForegroundColor Red; Start-Sleep -Milliseconds 800 }
        }
    }
}

Show-MainMenu
