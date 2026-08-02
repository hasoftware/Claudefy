# Security Policy

## Supply Chain Security

This package has **zero runtime dependencies**. The only code that runs is:

1. `bin/cli.js` — Detects your OS and spawns the platform-specific installer script
2. Platform installer scripts — Write config files to `~/.claude/`

There are **no install scripts** (`preinstall`, `postinstall`, `install`) in `package.json`. Code only executes when you explicitly run `npx @hasoftware/claudefy`.

## What the installer does

- Writes shell scripts to `~/.claude/` (statusline, notification hook, tab title hook)
- Merges settings into `~/.claude/settings.json`
- Optionally installs a Nerd Font via your system package manager
- Optionally registers an MCP server via `claude mcp add`
- All existing files are backed up with `.backup-<timestamp>` suffix before modification

## What the installer does NOT do

- Access network (except optional font download and DevRadar npm install, both with user consent)
- Read or transmit any personal data
- Modify files outside `~/.claude/` and your terminal config
- Run in the background after installation

## Reporting a Vulnerability

If you discover a security issue, please open a private security advisory on GitHub (https://github.com/hasoftware/Claudefy/security/advisories/new). Do not open a public issue for security vulnerabilities.

## Supported Versions

| Version | Supported |
| ------- | --------- |
| 1.x     | Yes       |
