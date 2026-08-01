<div align="center">

# Claudefy

### Make Claude Code yours.

A cross-platform toolkit that transforms Claude Code's default status bar into a fully-loaded developer cockpit — with smart notifications, auto-renamed terminal tabs, ten preset themes, and a curated safe-command allowlist.

**One install. Every machine. Every project.**

[![npm](https://img.shields.io/npm/v/@hasoftware/claudefy?style=flat-square&color=CB3837&logo=npm)](https://www.npmjs.com/package/@hasoftware/claudefy)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](https://opensource.org/licenses/MIT)
[![Platforms](https://img.shields.io/badge/platforms-Windows%20%7C%20macOS%20%7C%20Linux-blue?style=flat-square)](#installation)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Ready-FF6B35?style=flat-square&logo=anthropic)](https://claude.com/claude-code)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](https://github.com/hasoftware/Claudefy/pulls)
[![Telegram](https://img.shields.io/badge/Telegram-Join-26A5E4?style=flat-square&logo=telegram&logoColor=white)](https://t.me/hasoftware)

```bash
npx @hasoftware/claudefy
```

[Quick Start](#quick-start) · [Features](#features) · [Preview](#what-it-looks-like) · [Configuration](#configuration) · [FAQ](#faq)

</div>

---

```
   ____ _                 _       __
  / ___| | __ _ _   _  __| | ___ / _|_   _
 | |   | |/ _`| | | |/ _`|/ _ \ |_| | | |
 | |___| | (_| | |_| | (_| |  __/  _| |_| |
  \____|_|\__,_|\__,_|\__,_|\___|_|  \__, |
                                     |___/

       Claudefy v1.2.0  -  make Claude Code yours.
```

## Why Claudefy

Out of the box, Claude Code ships with a minimal status line. That works — until you find yourself asking:

- How much context do I have left?
- Am I about to blow through my 5-hour quota?
- Is the CI passing on my open PR?
- How much has this session cost so far?
- Which project am I even in right now?

Claudefy answers all of these at a glance, without leaving the chat. It is the productivity layer Claude Code is missing, and it installs in about thirty seconds.

## What it looks like

When you open Claude Code in a Node.js project with git, you will see this beneath the chat window:

```
 my-project    main 12  3d   Node 22.19.0    #42    Opus 4.7   01:33 ICT (46m)
 Context: 84%    5h: 24% 05:40    7d: 17%    $8.42    +616 -215    164.3k
```

**Line one — where you are**

| Segment | Meaning |
|---|---|
| `my-project` | Current project name |
| `main 12 3d` | Branch, 12 uncommitted changes, last commit 3 days ago |
| `Node 22.19.0` | Runtime auto-detected from your manifest |
| `#42` | Open PR number 42, checkmark means CI is green |
| `Opus 4.7` | Active Claude model |
| `01:33 ICT (46m)` | Hanoi clock and session duration |

**Line two — what you have spent**

| Segment | Meaning |
|---|---|
| `Context: 84%` | Remaining context window |
| `5h: 24% 05:40` | 5-hour quota usage and reset time |
| `7d: 17%` | 7-day quota usage |
| `$8.42` | Current session cost |
| `+616 -215` | Lines added and removed |
| `164.3k` | Total tokens |

Colors shift dynamically as thresholds are crossed: green below 50 percent, orange from 50 to 80 percent, red above 80 percent. You always know when to slow down.

## Features

**Powerline status bar (2 to 4 lines)**
Runtime detection, git state, open PRs, CI status, quota usage, session cost, token totals, and a Hanoi clock. A third line appears when [DevRadar](https://github.com/hasoftware/DevRadar) is installed (`npm install -g @hasoftware/devradar`), showing total lines of code, detected framework, and code ratio.

**18 smart widgets (v1.4.0)**
Safety and awareness built in: permission-mode badge (YOLO/Plan/AutoEdit), red alert when editing directly on main, battery, Docker containers, dev-server port probe, burn rate `$/h`, quota pace + reset countdown, auto-compact forecast (`~N turns→compact`), session velocity and phase (build vs explore), compact count, idle timer, uncommitted-pile warning, branch age vs main, merge-conflict radar, total output tokens today, and a usage streak. Everything expensive is cached and auto-skipped over SSH.

**Stop hook with notifications**
Plays a chime and shows a native toast when Claude finishes responding. Upgrades to an urgent alert when your quota is nearly exhausted, so you never miss a long-running task.

**SessionStart hook**
Automatically renames your terminal tab to match the project. No more hunting through five identical tabs to find the right one.

**Ten preset color themes (Windows)**
One Half Dark, Dracula, Tokyo Night, Catppuccin Mocha, Nord, Solarized Dark, Gruvbox Dark, Monokai, Synthwave 84, GitHub Dark. Swap between them from the Theme menu in seconds.

**Safe-command allowlist**
About fifty read-only commands pre-approved so you stop clicking "confirm" for harmless operations like `ls`, `cat`, `git status`, and the like.

**MCP sequential-thinking server**
Bundled and pre-wired so Claude can reason through complex problems with more structure.

**Automatic font installation**
JetBrainsMono Nerd Font installed via winget, brew, or direct download depending on your platform.

## Installation

### Requirements

- Claude Code CLI
- A terminal with Nerd Font support (Windows Terminal, GNOME Terminal, iTerm2, Alacritty, Kitty)
- Recommended: git, Node.js, and the GitHub CLI (`gh`) authenticated

### Quick start

**One command (recommended)**

```bash
npx @hasoftware/claudefy
```

Works on Windows, Linux, and macOS. Detects your platform and runs the right installer automatically.

Options: `--force`, `--skip-font`, `--skip-mcp`, `--skip-devradar`

**Manual install**

<details>
<summary>Windows</summary>

```powershell
cd windows
.\Claudefy.ps1
```

Or double-click `Claudefy.cmd`. See `windows/README.md` for details.

</details>

<details>
<summary>Linux</summary>

```bash
cd Linux
chmod +x claudefy.sh install-claudefy.sh lib/*.sh
./claudefy.sh
```

See `Linux/README.md` for details.

</details>

<details>
<summary>macOS</summary>

```bash
cd MACOS
chmod +x claudefy.sh install-claudefy.sh lib/*.sh
./claudefy.sh
```

See `MACOS/README.md` for details.

</details>

## The Claudefy menu

On Windows the menu offers four options: Install, Reset, Theme, About. On Linux and macOS the menu offers three: Install, Reset, About.

| Option | Action |
|---|---|
| Install | Installs the full kit |
| Reset | Removes the kit, keeping fonts and other unrelated `settings.json` fields |
| Theme | Switches Windows Terminal color scheme (Windows only) |
| About | Shows version, installed files, and author |

## Repository structure

```
Claudefy/
  windows/        For Windows 10 and 11, written in PowerShell
  Linux/          For any Linux distribution, written in bash
  MACOS/          For macOS, written in bash with Homebrew and osascript
```

All three share the same core feature set. Platform-specific differences are limited to font installation, notification delivery, and the Theme menu (Windows only, since color schemes work differently across Linux and macOS terminals).

## Configuration

Everything Claudefy writes lives under `~/.claude/` on Linux and macOS, or `%USERPROFILE%\.claude\` on Windows. Before modifying any file, the installer creates a timestamped backup with the suffix `.backup-<timestamp>`, so you can always roll back.

**Notification thresholds**

Open `notify-stop.ps1` (Windows) or `notify-stop.sh` (Linux, macOS) and adjust these variables at the top of the file:

| Variable | Purpose |
|---|---|
| `T_5H` | 5-hour quota warning threshold |
| `T_7D` | 7-day quota warning threshold |
| `T_OPUS_7D` | 7-day Opus quota warning threshold |
| `T_CONTEXT` | Context window warning threshold |
| `T_COST_USD` | Session cost warning threshold |

**Time zone**

Open `statusline-command.*` and change the value `7` in both occurrences of `AddHours(7)` (Windows) or `25200` (which equals `7 * 3600` seconds, on Linux and macOS) to your local UTC offset.

## FAQ

**Does Claudefy modify my existing Claude Code config?**
Yes, but safely. Every file is backed up with a timestamped suffix before any change. The Reset option restores everything except your fonts.

**Can I use this without DevRadar?**
Absolutely. DevRadar is optional. The third status line only appears when DevRadar is installed; the first two lines work regardless.

**Why is the Theme menu only on Windows?**
Windows Terminal exposes a clean JSON config that we can patch reliably. Linux and macOS terminals (GNOME Terminal, iTerm2, Alacritty, Kitty, and others) each handle colors differently, so a unified theme switcher is not feasible. You can still apply any theme you like manually.

**Does it work with non-English locales?**
Yes. Status line output uses neutral ASCII and Powerline glyphs. The clock label `ICT` reflects the bundled time zone and can be changed in `statusline-command.*`.

**How do I uninstall?**
Run the script again and pick Reset. All Claudefy-installed files are removed and your original `settings.json` is restored from backup.

## Contributing

Bug reports, feature requests, and pull requests are welcome. For quick discussion, join the Telegram channel below. For anything that touches behavior across platforms, please open an issue first so we can keep Windows, Linux, and macOS in sync.

## Contact

- Author: Hoang Anh Dev
- Organization: HASOFTWARE
- Telegram: [t.me/hasoftware](https://t.me/hasoftware)
- Repository: [github.com/hasoftware/Claudefy](https://github.com/hasoftware/Claudefy)

## License

MIT. Free to use, modify, and distribute, including for commercial purposes. Just keep the `LICENSE` file.

---

<div align="center">

If Claudefy saves you time, consider giving it a star. It helps other developers find the project.

</div>
