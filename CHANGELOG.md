# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
