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
C_DCYAN=$'\033[96m'
C_GREEN=$'\033[32m'
C_YELLOW=$'\033[33m'
C_RED=$'\033[31m'
C_GRAY=$'\033[90m'
C_WHITE=$'\033[97m'
C_RESET=$'\033[0m'

TOTAL_STEPS=6
CURRENT_STEP=0
START_TIME=$(date +%s)

step_start() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  local filled=$((CURRENT_STEP * 10 / TOTAL_STEPS))
  local empty=$((10 - filled))
  local bar=""
  for i in $(seq 1 $filled); do bar="${bar}█"; done
  for i in $(seq 1 $empty); do bar="${bar}░"; done
  printf '\n  %s[%d/%d]%s %s%s%s  %s[%s]%s\n' \
    "$C_DCYAN" "$CURRENT_STEP" "$TOTAL_STEPS" "$C_RESET" \
    "$C_WHITE" "$1" "$C_RESET" \
    "$C_GRAY" "$bar" "$C_RESET"
}
ok()   { printf '        %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$1"; }
warn() { printf '        %s!%s %s\n' "$C_YELLOW" "$C_RESET" "$1"; }
err()  { printf '        %s✗%s %s\n' "$C_RED" "$C_RESET" "$1"; }
info() { printf '          %s%s%s\n' "$C_GRAY" "$1" "$C_RESET"; }
step() { printf '        %s> %s%s\n' "$C_CYAN" "$1" "$C_RESET"; }

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
    info "Backed up -> $1.backup-$ts"
  fi
}

# ---------------------------------------------------------------------------
# Welcome
# ---------------------------------------------------------------------------
echo ""
printf '  %s██%s %sClaudefy%s — make Claude Code yours.\n' "$C_CYAN" "$C_RESET" "$C_WHITE" "$C_RESET"
printf '     %shttps://github.com/hasoftware/Claudefy%s\n' "$C_GRAY" "$C_RESET"
echo ""
printf '     %s◆ Statusline  ◆ Hooks  ◆ Font  ◆ MCP  ◆ DevRadar%s\n' "$C_DCYAN" "$C_RESET"
echo ""
confirm "  Proceed?" || { echo "  Cancelled."; exit 0; }

# ---------------------------------------------------------------------------
# 1. Pre-flight checks
# ---------------------------------------------------------------------------
step_start "Pre-flight checks"
have() { command -v "$1" >/dev/null 2>&1; }

have bash    && ok "bash $(bash --version | head -1 | awk '{print $4}')" || { err "bash not found"; exit 1; }
have claude  && ok "claude: $(command -v claude)" || { err "Claude Code CLI not found. https://claude.com/claude-code"; exit 1; }
have jq      && ok "jq: $(jq --version)" || { err "jq is required. Install: sudo apt install jq  (or your distro's package manager)"; exit 1; }
have git     && ok "git: $(git --version | awk '{print $3}')" || warn "git not found (git block disabled in statusLine)"
have node    && ok "node: $(node --version)" || warn "node not found (MCP server cannot run)"
have gh      && ok "gh: $(gh --version | head -1 | awk '{print $3}')" || warn "gh CLI not found (PR/CI block disabled)"

CLAUDE_DIR="$HOME/.claude"
mkdir -p "$CLAUDE_DIR"
ok "Claude dir: $CLAUDE_DIR"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

if [ ! -d "$LIB_DIR" ]; then
  err "lib/ folder not found next to installer. Expected: $LIB_DIR"
  exit 1
fi

# ---------------------------------------------------------------------------
# 2. Install JetBrainsMono Nerd Font
# ---------------------------------------------------------------------------
step_start "Nerd Font"
if [ "$SKIP_FONT" = "1" ]; then
  info "Skipped (--skip-font)"
else
  FONT_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
  if [ -d "$FONT_DIR" ] && ls "$FONT_DIR"/*.ttf >/dev/null 2>&1; then
    ok "Already installed at $FONT_DIR"
  else
    step "Downloading JetBrainsMono Nerd Font from GitHub"
    mkdir -p "$FONT_DIR"
    TMP_ZIP=$(mktemp)
    URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
    if have curl; then
      curl -fSL "$URL" -o "$TMP_ZIP" || { err "Download failed"; rm -f "$TMP_ZIP"; exit 1; }
    elif have wget; then
      wget -q "$URL" -O "$TMP_ZIP" || { err "Download failed"; rm -f "$TMP_ZIP"; exit 1; }
    else
      err "Need curl or wget to download font. Or use --skip-font"; exit 1
    fi
    step "Extracting"
    if have unzip; then
      unzip -q -o "$TMP_ZIP" -d "$FONT_DIR"
    else
      err "unzip not found. Install: sudo apt install unzip"; rm -f "$TMP_ZIP"; exit 1
    fi
    rm -f "$TMP_ZIP"
    have fc-cache && fc-cache -f "$FONT_DIR" >/dev/null 2>&1
    ok "Installed at $FONT_DIR"
    info "Set your terminal font to 'JetBrainsMono Nerd Font' manually if needed"
  fi
fi

# ---------------------------------------------------------------------------
# 3. Copy helper scripts
# ---------------------------------------------------------------------------
step_start "Helper scripts"
for name in statusline-command.sh notify-stop.sh set-title.sh; do
  src="$LIB_DIR/$name"
  dst="$CLAUDE_DIR/$name"
  [ ! -f "$src" ] && { err "Missing $src"; exit 1; }
  backup_file "$dst"
  cp -f "$src" "$dst"
  chmod +x "$dst"
  ok "$name"
done

# ---------------------------------------------------------------------------
# 4. Merge Claude Code settings.json
# ---------------------------------------------------------------------------
step_start "Settings merge"
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
echo "$EXIST" | jq empty 2>/dev/null || {
  warn "Could not parse existing settings.json - starting fresh"
  EXIST='{}'
}

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
ok "settings.json merged ($allow_count allow entries)"

# ---------------------------------------------------------------------------
# 5. MCP server
# ---------------------------------------------------------------------------
step_start "MCP server"
if [ "$SKIP_MCP" = "1" ]; then
  info "Skipped (--skip-mcp)"
elif ! have node; then
  warn "Node not found - skipping MCP"
else
  if claude mcp list 2>&1 | grep -q 'sequential-thinking'; then
    ok "Already configured"
  else
    claude mcp add sequential-thinking --scope user -- npx -y '@modelcontextprotocol/server-sequential-thinking' >/dev/null 2>&1
    ok "Added"
  fi
fi

# ---------------------------------------------------------------------------
# 6. DevRadar (optional - powers Line 3 LOC widget)
# ---------------------------------------------------------------------------
step_start "DevRadar"
if [ "$SKIP_DEVRADAR" = "1" ]; then
  info "Skipped (--skip-devradar)"
elif have devradar; then
  ok "Already installed: $(command -v devradar)"
elif ! have npm; then
  warn "npm not available - skipping. Install Node.js then run: npm install -g devradar"
else
  info "DevRadar is a code analyzer (LOC, languages, frameworks)."
  info "Powers Line 3 of the statusLine. Repo: https://github.com/hasoftware/DevRadar"
  if confirm "Install DevRadar globally via npm now?"; then
    if npm install -g devradar; then
      ok "DevRadar installed - Line 3 will show after next message"
    else
      warn "npm install failed - try manually: npm install -g devradar"
    fi
  else
    info "Skipped. To enable Line 3 later, run: npm install -g devradar"
  fi
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
ELAPSED=$(( $(date +%s) - START_TIME ))
echo ""
printf '  %s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n' "$C_DCYAN" "$C_RESET"
echo ""
printf '  %s✅ All %d steps completed%s in %ds\n' "$C_GREEN" "$TOTAL_STEPS" "$C_RESET" "$ELAPSED"
echo ""
printf '  %s→%s Close & reopen terminal, then run %sclaude%s\n' "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET"
echo ""
printf '     %sBackups saved with .backup-<timestamp> suffix%s\n' "$C_GRAY" "$C_RESET"
printf '     %sTelegram: t.me/hasoftware  |  github.com/hasoftware/Claudefy%s\n' "$C_GRAY" "$C_RESET"
echo ""
