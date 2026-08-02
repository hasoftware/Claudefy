# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.5.1] - 2026-08-02

A release about cost. Adding the load widget in 1.5.0 prompted the obvious
question — what does the status line itself cost? — and profiling turned up a
long-standing bug plus several widgets doing far more work than they needed to.
Measured on Windows, a render went from 1375ms/412ms (wall/CPU) to 489ms/131ms.

### Fixed
- **`gh pr list` ran on every single render** on any branch without an open PR,
  network round trip and all. The cache stored the result but freshness was
  inferred from the payload, so "cached: there is no PR" was indistinguishable
  from "cache expired". Freshness is now tracked separately. Observed on a
  machine with six concurrent sessions: 16 `gh` processes per 45s -> 2 per 60s.
- The DevRadar cache had the same flaw, and additionally never stamped the
  cache when a scan produced nothing, so an unparseable repo re-scanned forever.
- On Linux/macOS the render cache returned early before the CPU/RAM code ran,
  and its key didn't include those values, so a load change alone was masked by
  a cache hit. That block now runs *before* the cache check and both values are
  part of the key.

### Changed
- **No `refreshInterval` by default.** 1.5.1 briefly shipped `10`; measurement
  retired the idea. Claude Code runs the status line through Git Bash, so each
  render costs three processes (bash -> pwsh -> conhost), and a timer pays that
  toll forever in every open session at once — six sessions produced ~156
  processes a minute to redraw a bar nobody was looking at. Event-driven renders
  already fire every few seconds while you work, which is when the numbers
  matter. Add `"refreshInterval": <seconds>` to `statusLine` yourself if you
  want a live readout while idle; re-running the installer now preserves it.
- Commit age is formatted locally from `%ct` instead of parsing `%cr`, using
  git's own thresholds (90s / 90min / 36h / 14d / 8w / 12mo) so the label is
  unchanged — and it no longer breaks when git isn't printing English.

### Performance
- **`Get-Content -Tail 300` was costing ~20 seconds per render** on Windows and
  got worse the longer a session ran. It counts lines by walking the file
  backwards, and a transcript is JSONL whose lines are whole messages, often
  tens of KB each: 231ms at 1.35MB, **19,698ms at 2.87MB**. Since renders are
  requested every couple of seconds and Claude Code kills the in-flight process
  when a new one is due, the machine sat permanently spawning and killing a
  20-second script — the sawtooth you'd see in Task Manager, filed under "Git
  for Windows" because Claude Code launches the status line through Git Bash.
  Now read by byte offset via `FileStream.Seek`, the way `tail -c` already did
  it on Linux/macOS: **22ms**, and flat regardless of session length.
- Turn and compact counts are accumulated incrementally. Transcripts are
  append-only, so a stored byte checkpoint means each render counts only what
  was added since — instead of two full-file scans (~108ms at 2.9MB, and
  climbing) on every message. Counting stops at the last newline so a record
  still being written is never half-counted; verified exact against full scans
  across successive appends.
- Runtime detection is cached 60s per cwd on Windows, as it already was on
  Linux/macOS. Every branch of it shells out to a version flag, so each render
  had been spawning `node --version` (or python/rustc/go/dotnet/java/ruby) just
  to be told the same number again.
- Transcript widgets (turns, session phase, compact count) share one cache keyed
  on the transcript's size and mtime, so an idle session re-reads nothing.
- Git dropped from six processes per render to one. `status --porcelain=v2
  --branch` yields branch, ahead/behind and dirty count together, and stash
  count plus commit time hang off a cache keyed on the HEAD commit. Line 3 reuses
  that same commit id instead of calling `rev-parse` again.
- Dev-server port probe cached 30s. With every port closed it waited out
  120ms x 5 ports, spending up to 600ms per render to discover nothing.
- Windows CPU/RAM reads raw perf counters and diffs them between renders, the
  approach `/proc/stat` already gives us on Linux. `Win32_Processor`'s
  `LoadPercentage` samples internally for a full second (~1050ms) and
  `Win32_OperatingSystem` cost ~157ms, making the load widget the most expensive
  thing on the line — a poor trade for something whose job is to report that the
  machine is busy. The raw counters answer in ~6ms and ~7ms.
- Those counters exceed 2^53, so they are handled as `[long]`; `[double]` was
  rounding them and serialising the timestamp as `1.34E+17`.

## [1.5.0] - 2026-08-02

### Added
- CPU / RAM usage widget (Line 4) on all three platforms, cached 30s so it
  doesn't refresh faster than needed. Reads `/proc/stat` + `/proc/meminfo`
  on Linux, `top`/`vm_stat`/`sysctl` on macOS, `Win32_Processor`/
  `Win32_OperatingSystem` via CIM on Windows.
- On Linux/macOS this widget renders as its own line while in SSH compact
  mode (which otherwise drops Line 4 entirely) — seeing free RAM/CPU on the
  box you just SSH'd into is the main reason to want it.

## [1.4.5] - 2026-08-02

### Fixed
- Removed a personal email address accidentally published in `package.json`
  (`author`/`contributors`) and `SECURITY.md`. Security reports now go
  through GitHub Security Advisories instead of email.

## [1.4.4] - 2026-08-01

### Changed
- Releases are now published to npm automatically via GitHub Actions with
  npm Trusted Publishing (OIDC) + provenance. No functional changes.

## [1.4.3] - 2026-08-01

### Changed
- Line 3 tech segment: when DevRadar detects no framework (shell repos,
  Swift projects, ...), fall back to the dominant language instead of
  hiding the segment.
- Burn rate `($/h)` is hidden when session cost is 0 (subscription
  sessions without cost data).

## [1.4.2] - 2026-08-01

### Changed — full 4-line statusline over SSH without flicker (macOS/Linux)
- Field extraction collapsed from ~16 `jq` spawns to a single `jq` pass.
- New render cache (TTL 10s): when the displayed values are unchanged, the
  previous render is returned verbatim in ~20ms — byte-identical output lets
  the host UI diff to a no-op instead of repainting, killing idle flicker.
- Runtime detection (node/python/... version probes) cached 60s per cwd.
- `CLAUDEFY_COMPACT=0` over SSH is now the recommended way to get all 4
  lines remotely; compact remains the SSH default.

## [1.4.1] - 2026-08-01

### Fixed
- Windows installer printed a literal `━━ * 44` instead of the separator
  line (`* 44` was parsed as extra Write-Host arguments, not string repeat).

## [1.4.0] - 2026-08-01

### Added — 18 smart widgets across all three platforms
- **Line 1**: permission-mode badge (YOLO/Plan/AutoEdit — shown even in SSH
  compact mode), on-main red alert when editing directly on main/master,
  battery (discharging/low), running Docker containers, dev-server port probe
  (3000/5173/8080/4200/8000).
- **Line 2**: burn rate `$/h` inside the cost segment, quota pace arrow when
  burning faster than the 5h window elapses, reset countdown once 5h >= 70%,
  auto-compact forecast (`~N turns -> compact`), session velocity (turns/h),
  session phase (build vs explore), compact count, idle timer.
- **Line 3**: uncommitted-pile warning (>=300 changed lines), branch age vs
  main with behind count, conflict radar via `git merge-tree` (git >= 2.38).
- **Line 4**: total output tokens across all sessions today, usage streak
  (consecutive days).
- All expensive widgets are cached (15s–1h TTL) and skipped in SSH compact
  mode; every widget degrades gracefully when its data source is missing.

## [1.3.5] - 2026-08-01

### Added
- Compact statusline mode, auto-enabled over SSH (`SSH_CONNECTION`/`SSH_TTY`):
  renders 2 lines and skips expensive per-refresh work (gh PR check, GitHub
  update check, DevRadar scan, runtime detection, .env scan) to stop redraw
  flicker on remote connections. Override with `CLAUDEFY_COMPACT=0/1`.

## [1.3.4] - 2026-08-01

### Fixed
- macOS statusline rendered nothing: `render_line` used `local -n`
  (namerefs, bash 4.3+) but macOS ships bash 3.2. Rewritten with
  `eval`-based indirection in both macOS and Linux statuslines.
- Update badge / .env warning / turns counter printed literal `$'\xe2...'`
  instead of icons ($'..' has no meaning inside double quotes).
- Statusline branding stuck at v1.2.0, causing a false "update available"
  badge; version strings synced to the package version.

## [1.3.3] - 2026-08-01

### Fixed
- DevRadar step always failed with "npm failed": installers ran
  `npm install -g devradar` but the package is published as
  `@hasoftware/devradar`. Fixed in all three installers and docs.

## [1.3.2] - 2026-07-31

### Fixed
- macOS/Linux installer crashed with `Exit code 143` at the first spinner step:
  under `set -e`, `wait` on the killed spinner process returned 143 (SIGTERM)
  and aborted the whole script. `kill`/`wait` in `stop_spin` are now
  failure-tolerant (`|| true`).

## [1.3.1] - 2025-05-25

### Added
- CI pipeline (GitHub Actions) testing across Windows, macOS, Linux + Node 18/20/22
- Test suite for CLI entry point
- CHANGELOG.md
- `package-lock.json` for reproducible installs
- `funding` field in package.json

### Security
- Zero runtime dependencies — minimal supply chain attack surface
- No install scripts (`preinstall`/`postinstall`) — safe to install
- All operations are explicit and user-initiated via `npx`

## [1.3.0] - 2025-05-25

### Changed
- Installer UI redesigned with animated spinner (braille dots) per step
- Each step shows `⠋⠙⠹⠸...` while working, then `✓ result` when done
- PowerShell uses background runspace, bash uses background process

## [1.2.2] - 2025-05-25

### Changed
- Installer UI redesigned with progress bar style `[n/7] Step [██░░]`

## [1.2.1] - 2025-05-25

### Fixed
- `Get-ChildItem -Filter` array parameter bug in installer summary

## [1.2.0] - 2025-05-24

### Added
- Smart Model Hint: suggests Sonnet when Opus quota is high (≥60% → `→Sonnet?`, ≥80% → `→Sonnet!`)
- Stats Dashboard: session stats saved to `~/.claude/claudefy-stats.jsonl`, viewable from menu
- Session turn counter in statusline
- `.env` safety warning when `.env*` files aren't gitignored
- Auto-update checker (checks GitHub Releases API once per day)
- Dynamic 7-day quota label showing remaining days (e.g., `3d: 40%`)

## [1.0.1] - 2025-05-23

### Added
- Optional DevRadar Line 3 integration
- Multi-platform support: Linux and macOS

## [1.0.0] - 2025-05-22

### Added
- Initial release
- Powerline-style 2-line statusline (folder, git, runtime, PR/CI, model, clock, quota, cost, tokens)
- Stop hook with native notifications and quota alerts
- SessionStart hook for dynamic terminal tab naming
- JetBrainsMono Nerd Font auto-installation
- MCP sequential-thinking server setup
- Permission allowlist (~50 read-only commands)
- Windows Terminal font configuration
- 10 preset color themes (Windows)

[1.3.1]: https://github.com/hasoftware/Claudefy/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/hasoftware/Claudefy/compare/v1.2.2...v1.3.0
[1.2.2]: https://github.com/hasoftware/Claudefy/compare/v1.2.1...v1.2.2
[1.2.1]: https://github.com/hasoftware/Claudefy/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/hasoftware/Claudefy/compare/v1.0.1...v1.2.0
[1.0.1]: https://github.com/hasoftware/Claudefy/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/hasoftware/Claudefy/releases/tag/v1.0.0
