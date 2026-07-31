#!/usr/bin/env bash
#
# Claudefy installer for Linux.
#
# Author     : Hoang Anh Dev
# Admin      : HASOFTWARE
# Telegram   : https://t.me/hasoftware
# Repository : https://github.com/hasoftware/Claudefy
#
# Usage:
#   ./install-claudefy.sh [--force] [--skip-font] [--skip-mcp] [--skip-devradar]
#
set -e
export LANG=en_US.UTF-8

# ---------------------------------------------------------------------------
# Args
# ---------------------------------------------------------------------------
FORCE=0
SKIP_FONT=0
SKIP_MCP=0
SKIP_DEVRADAR=0
for arg in "$@"; do
  case "$arg" in
    --force)         FORCE=1 ;;
    --skip-font)     SKIP_FONT=1 ;;
    --skip-mcp)      SKIP_MCP=1 ;;
    --skip-devradar) SKIP_DEVRADAR=1 ;;
    -h|--help)
      sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
  esac
done

# ---------------------------------------------------------------------------
# UI helpers
# ---------------------------------------------------------------------------
C_CYAN=$'\033[36m'
C_GREEN=$'\033[32m'
C_YELLOW=$'\033[33m'
C_RED=$'\033[31m'
C_GRAY=$'\033[90m'
C_WHITE=$'\033[97m'
C_RESET=$'\033[0m'

TOTAL_STEPS=6
START_TIME=$(date +%s)
SPIN_PID=""

start_spin() {
  local msg="$1"
  ( while true; do
      for c in ⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏; do
        printf '\r  %s%s%s %s   ' "$C_CYAN" "$c" "$C_RESET" "$msg"
        sleep 0.08
      done
    done ) &
  SPIN_PID=$!
}

stop_spin() {
  local msg="$1" ok="${2:-1}"
  kill "$SPIN_PID" 2>/dev/null || true
  wait "$SPIN_PID" 2>/dev/null || true
  SPIN_PID=""
  printf '\033[2K\r'
  if [ "$ok" = "1" ]; then
    printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$msg"
  else
    printf '  %s!%s %s\n' "$C_YELLOW" "$C_RESET" "$msg"
  fi
}

detail() { printf '      %s%s%s\n' "$C_GRAY" "$1" "$C_RESET"; }
err()    { printf '  %s✗ %s%s\n' "$C_RED" "$1" "$C_RESET"; }

confirm() {
  [ "$FORCE" = "1" ] && return 0
  printf '%s [Y/n] ' "$1"
  read -r ans
  case "$ans" in Y|y|"") return 0 ;; *) return 1 ;; esac
}

backup_file() {
  if [ -f "$1" ]; then
    local ts; ts=$(date +'%Y%m%d-%H%M%S')
    cp -p "$1" "$1.backup-$ts"
  fi
}

# ---------------------------------------------------------------------------
# Welcome
# ---------------------------------------------------------------------------
echo ""
printf '  %s██%s %sClaudefy%s — make Claude Code yours.\n' "$C_CYAN" "$C_RESET" "$C_WHITE" "$C_RESET"
printf '     %shttps://github.com/hasoftware/Claudefy%s\n' "$C_GRAY" "$C_RESET"
echo ""
printf '     %s◆ Statusline  ◆ Hooks  ◆ Font  ◆ MCP  ◆ DevRadar%s\n' "$C_CYAN" "$C_RESET"
echo ""
confirm "  Proceed?" || { echo "  Cancelled."; exit 0; }

# ---------------------------------------------------------------------------
# 1. Pre-flight checks
# ---------------------------------------------------------------------------
start_spin "Checking requirements..."
have() { command -v "$1" >/dev/null 2>&1; }

have bash   || { stop_spin "bash not found" 0; exit 1; }
have claude || { stop_spin "Claude Code CLI not found" 0; exit 1; }
have jq     || { stop_spin "jq is required (sudo apt install jq)" 0; exit 1; }

tools="bash, claude, jq"
have git  && tools="$tools, git"
have node && tools="$tools, node"
have gh   && tools="$tools, gh"

CLAUDE_DIR="$HOME/.claude"
mkdir -p "$CLAUDE_DIR"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

if [ ! -d "$LIB_DIR" ]; then
  stop_spin "lib/ folder not found" 0; exit 1
fi
stop_spin "Pre-flight — $tools"

# ---------------------------------------------------------------------------
# 2. Install JetBrainsMono Nerd Font
# ---------------------------------------------------------------------------
start_spin "Installing Nerd Font..."
if [ "$SKIP_FONT" = "1" ]; then
  stop_spin "Nerd Font — skipped" 0
else
  FONT_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
  if [ -d "$FONT_DIR" ] && ls "$FONT_DIR"/*.ttf >/dev/null 2>&1; then
    stop_spin "Nerd Font — already installed"
  else
    mkdir -p "$FONT_DIR"
    TMP_ZIP=$(mktemp)
    URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
    if have curl; then
      curl -fSL "$URL" -o "$TMP_ZIP" 2>/dev/null || { stop_spin "Nerd Font — download failed" 0; rm -f "$TMP_ZIP"; exit 1; }
    elif have wget; then
      wget -q "$URL" -O "$TMP_ZIP" || { stop_spin "Nerd Font — download failed" 0; rm -f "$TMP_ZIP"; exit 1; }
    else
      stop_spin "Nerd Font — need curl or wget (use --skip-font)" 0; exit 1
    fi
    if have unzip; then
      unzip -q -o "$TMP_ZIP" -d "$FONT_DIR"
    else
      stop_spin "Nerd Font — unzip not found" 0; rm -f "$TMP_ZIP"; exit 1
    fi
    rm -f "$TMP_ZIP"
    have fc-cache && fc-cache -f "$FONT_DIR" >/dev/null 2>&1
    stop_spin "Nerd Font — installed"
    detail "Set terminal font to 'JetBrainsMono Nerd Font' manually"
  fi
fi

# ---------------------------------------------------------------------------
# 3. Copy helper scripts
# ---------------------------------------------------------------------------
start_spin "Writing helper scripts..."
for name in statusline-command.sh notify-stop.sh set-title.sh; do
  src="$LIB_DIR/$name"
  dst="$CLAUDE_DIR/$name"
  [ ! -f "$src" ] && { stop_spin "Missing $src" 0; exit 1; }
  backup_file "$dst"
  cp -f "$src" "$dst"
  chmod +x "$dst"
done
stop_spin "Helper scripts — 3 files written"

# ---------------------------------------------------------------------------
# 4. Merge Claude Code settings.json
# ---------------------------------------------------------------------------
start_spin "Merging settings..."
SETTINGS="$CLAUDE_DIR/settings.json"
backup_file "$SETTINGS"

SL_PATH="$CLAUDE_DIR/statusline-command.sh"
NT_PATH="$CLAUDE_DIR/notify-stop.sh"
TT_PATH="$CLAUDE_DIR/set-title.sh"

# Build kit-allow list
KIT_ALLOWS=$(cat <<'JSON'
[
  "Bash(git push:*)","Bash(git push origin main)","Bash(git push origin *)",
  "Bash(ls:*)","Bash(pwd)","Bash(cat:*)","Bash(head:*)","Bash(tail:*)",
  "Bash(file:*)","Bash(wc:*)","Bash(echo:*)","Bash(date:*)","Bash(which:*)",
  "Bash(env)","Bash(printenv:*)",
  "Bash(git status:*)","Bash(git log:*)","Bash(git diff:*)",
  "Bash(git branch:*)","Bash(git remote:*)","Bash(git show:*)",
  "Bash(git fetch:*)","Bash(git rev-parse:*)","Bash(git rev-list:*)",
  "Bash(git symbolic-ref:*)","Bash(git config --get:*)",
  "Bash(git stash list:*)","Bash(git tag:*)","Bash(git blame:*)",
  "Bash(git ls-files:*)","Bash(git describe:*)",
  "Bash(node --version)","Bash(npm --version)","Bash(npm ls:*)",
  "Bash(npm run test:*)","Bash(npm test:*)",
  "Bash(python --version)","Bash(python -V)","Bash(pip list:*)","Bash(pip show:*)",
  "Bash(pwsh --version)","Bash(git --version)","Bash(gh --version)",
  "Bash(go version)","Bash(cargo --version)","Bash(rustc --version)",
  "Bash(gh pr list:*)","Bash(gh pr view:*)","Bash(gh pr diff:*)",
  "Bash(gh issue list:*)","Bash(gh issue view:*)",
  "Bash(gh repo view:*)","Bash(gh api repos:*)"
]
JSON
)

# Existing settings or empty object
if [ -f "$SETTINGS" ]; then
  EXIST=$(cat "$SETTINGS")
else
  EXIST='{}'
fi

# Sanity check JSON parse
echo "$EXIST" | jq empty 2>/dev/null || EXIST='{}'

NEW=$(echo "$EXIST" | jq \
  --arg sl "$SL_PATH" --arg nt "$NT_PATH" --arg tt "$TT_PATH" \
  --argjson allows "$KIT_ALLOWS" '
  .statusLine = { type: "command", command: ("bash \"" + $sl + "\"") }
  | .hooks = (.hooks // {})
  | .hooks.SessionStart = [ { matcher: "", hooks: [ { type: "command", command: ("bash \"" + $tt + "\"") } ] } ]
  | .hooks.Stop         = [ { matcher: "", hooks: [ { type: "command", command: ("bash \"" + $nt + "\"") } ] } ]
  | .permissions = (.permissions // {})
  | .permissions.allow = ((.permissions.allow // []) + $allows | unique)
')

echo "$NEW" > "$SETTINGS"
allow_count=$(echo "$NEW" | jq '.permissions.allow | length')
stop_spin "Settings merged — $allow_count allow entries"

# ---------------------------------------------------------------------------
# 5. MCP server
# ---------------------------------------------------------------------------
start_spin "Setting up MCP server..."
if [ "$SKIP_MCP" = "1" ]; then
  stop_spin "MCP server — skipped" 0
elif ! have node; then
  stop_spin "MCP server — node not found" 0
else
  if claude mcp list 2>&1 | grep -q 'sequential-thinking'; then
    stop_spin "MCP server — already configured"
  else
    claude mcp add sequential-thinking --scope user -- npx -y '@modelcontextprotocol/server-sequential-thinking' >/dev/null 2>&1
    stop_spin "MCP server — added"
  fi
fi

# ---------------------------------------------------------------------------
# 6. DevRadar (optional - powers Line 3 LOC widget)
# ---------------------------------------------------------------------------
if [ "$SKIP_DEVRADAR" = "1" ]; then
  start_spin "DevRadar..."; stop_spin "DevRadar — skipped" 0
elif have devradar; then
  start_spin "DevRadar..."; stop_spin "DevRadar — already installed"
elif ! have npm; then
  start_spin "DevRadar..."; stop_spin "DevRadar — npm not available" 0
else
  printf '\n  %s?%s DevRadar powers Line 3 (LOC, frameworks). Install globally?\n' "$C_CYAN" "$C_RESET"
  if confirm "   "; then
    start_spin "Installing DevRadar..."
    if npm install -g devradar >/dev/null 2>&1; then
      stop_spin "DevRadar — installed"
    else
      stop_spin "DevRadar — npm failed" 0
    fi
  else
    start_spin "DevRadar..."; stop_spin "DevRadar — skipped" 0
  fi
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
ELAPSED=$(( $(date +%s) - START_TIME ))
echo ""
printf '  %s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n' "$C_CYAN" "$C_RESET"
echo ""
printf '  %s✅ All %d steps completed%s in %ds\n' "$C_GREEN" "$TOTAL_STEPS" "$C_RESET" "$ELAPSED"
echo ""
printf '  %s→%s Close & reopen terminal, then run %sclaude%s\n' "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET"
echo ""
printf '     %sBackups saved with .backup-<timestamp> suffix%s\n' "$C_GRAY" "$C_RESET"
printf '     %sTelegram: t.me/hasoftware  |  github.com/hasoftware/Claudefy%s\n' "$C_GRAY" "$C_RESET"
echo ""
