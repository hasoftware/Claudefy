#!/usr/bin/env bash
#
# Claudefy - make Claude Code yours. Interactive menu (Linux).
#
# Author     : Hoang Anh Dev
# Admin      : HASOFTWARE
# Telegram   : https://t.me/hasoftware
# Repository : https://github.com/hasoftware/Claudefy
#
set -e
export LANG=en_US.UTF-8

VERSION="1.2.0"
AUTHOR="Hoang Anh Dev"
ADMIN="HASOFTWARE"
TELEGRAM="https://t.me/hasoftware"
REPO="https://github.com/hasoftware/Claudefy"

CLAUDE_DIR="$HOME/.claude"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALLER="$SCRIPT_DIR/install-claudefy.sh"

C_CYAN=$'\033[36m'
C_GREEN=$'\033[32m'
C_YELLOW=$'\033[33m'
C_RED=$'\033[31m'
C_GRAY=$'\033[90m'
C_WHITE=$'\033[37m'
C_RESET=$'\033[0m'

clear_screen() { printf '\033[2J\033[H'; }

banner() {
  clear_screen
  cat <<BANNER
${C_CYAN}
   ____ _                 _       __
  / ___| | __ _ _   _  __| | ___ / _|_   _
 | |   | |/ _\`| | | |/ _\`|/ _ \\ |_| | | |
 | |___| | (_| | |_| | (_| |  __/  _| |_| |
  \\____|_|\\__,_|\\__,_|\\__,_|\\___|_|  \\__, |
                                     |___/ ${C_RESET}

       ${C_YELLOW}Claudefy${C_RESET} ${C_GRAY}v${VERSION}  -  ${C_WHITE}make Claude Code yours.${C_RESET}
       ${C_GRAY}by ${AUTHOR}  -  ${C_YELLOW}${ADMIN}${C_RESET}

BANNER
}

section() {
  printf '\n%s%s%s\n  %s\n%s%s%s\n' \
    "$C_CYAN" "$(printf '=%.0s' {1..60})" "$C_RESET" \
    "$1" \
    "$C_CYAN" "$(printf '=%.0s' {1..60})" "$C_RESET"
}

pause_continue() {
  echo
  printf '%sPress Enter to return to menu...%s' "$C_GRAY" "$C_RESET"
  read -r _
}

# ---------------------------------------------------------------------------
# 1. Install
# ---------------------------------------------------------------------------
do_install() {
  section "1. Install Claudefy"
  if [ ! -f "$INSTALLER" ]; then
    printf '  %s[X]%s install-claudefy.sh not found at: %s\n' "$C_RED" "$C_RESET" "$INSTALLER"
    printf '      Make sure both scripts are in the same folder.\n'
    pause_continue; return
  fi
  bash "$INSTALLER"
  pause_continue
}

# ---------------------------------------------------------------------------
# 2. Reset to default
# ---------------------------------------------------------------------------
do_reset() {
  section "2. Reset to Default"
  cat <<EOM
  This will:
    - Remove kit's statusLine, SessionStart and Stop hooks from settings.json
    - Remove kit-added permission allowlist entries
    - Delete statusline-command.sh, notify-stop.sh, set-title.sh

  It WILL NOT:
    - Uninstall JetBrainsMono Nerd Font
    - Remove MCP servers
    - Delete your other settings.json fields

EOM
  printf 'Proceed? (type RESET to confirm) '
  read -r ans
  if [ "$ans" != "RESET" ]; then
    printf '  %sCancelled.%s\n' "$C_YELLOW" "$C_RESET"
    pause_continue; return
  fi

  SETTINGS="$CLAUDE_DIR/settings.json"
  if [ -f "$SETTINGS" ] && command -v jq >/dev/null 2>&1; then
    cp -p "$SETTINGS" "$SETTINGS.backup-$(date +'%Y%m%d-%H%M%S')"
    KIT_ALLOWS=$(cat <<'JSON'
[
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
    NEW=$(cat "$SETTINGS" | jq --argjson kits "$KIT_ALLOWS" '
      (if .statusLine.command and (.statusLine.command | test("statusline-command\\.sh")) then del(.statusLine) else . end)
      | (if .hooks.SessionStart then
           .hooks.SessionStart = (.hooks.SessionStart | map(select(.hooks // [] | any(.command | test("set-title\\.sh")) | not)))
           | if (.hooks.SessionStart | length) == 0 then del(.hooks.SessionStart) else . end
         else . end)
      | (if .hooks.Stop then
           .hooks.Stop = (.hooks.Stop | map(select(.hooks // [] | any(.command | test("notify-stop\\.sh")) | not)))
           | if (.hooks.Stop | length) == 0 then del(.hooks.Stop) else . end
         else . end)
      | (if .hooks and ((.hooks | length) == 0) then del(.hooks) else . end)
      | (if .permissions.allow then
           .permissions.allow = (.permissions.allow - $kits)
         else . end)
    ')
    echo "$NEW" > "$SETTINGS"
    printf '  %s[OK]%s settings.json cleaned\n' "$C_GREEN" "$C_RESET"
  fi

  for f in statusline-command.sh notify-stop.sh set-title.sh; do
    if [ -f "$CLAUDE_DIR/$f" ]; then
      rm -f "$CLAUDE_DIR/$f"
      printf '  %s[-]%s Deleted %s\n' "$C_GREEN" "$C_RESET" "$f"
    fi
  done

  echo
  printf '  %sReset complete. Restart Claude Code.%s\n' "$C_CYAN" "$C_RESET"
  pause_continue
}

# ---------------------------------------------------------------------------
# 3. About
# ---------------------------------------------------------------------------
do_about() {
  section "3. About"
  echo
  printf '  %sClaudefy%s v%s\n' "$C_YELLOW" "$C_RESET" "$VERSION"
  echo "  Make Claude Code yours - customization kit for Linux"
  echo
  printf '  Author      : %s%s%s\n' "$C_WHITE" "$AUTHOR" "$C_RESET"
  printf '  Admin       : %s%s%s\n' "$C_YELLOW" "$ADMIN" "$C_RESET"
  printf '  Telegram    : %s%s%s\n' "$C_CYAN" "$TELEGRAM" "$C_RESET"
  printf '  Repository  : %s%s%s\n' "$C_CYAN" "$REPO" "$C_RESET"
  echo
  echo "  Components installed by this kit:"
  for n in statusline-command.sh notify-stop.sh set-title.sh settings.json; do
    if [ -f "$CLAUDE_DIR/$n" ]; then
      printf '    %s[OK]%s %s\n' "$C_GREEN" "$C_RESET" "$n"
    else
      printf '    %s[--]%s %s\n' "$C_GRAY" "$C_RESET" "$n"
    fi
  done
  echo
  pause_continue
}

# ---------------------------------------------------------------------------
# 4. Stats Dashboard
# ---------------------------------------------------------------------------
do_stats() {
  section "4. Stats Dashboard"
  STATS_FILE="$HOME/.claude/claudefy-stats.jsonl"
  if [ ! -f "$STATS_FILE" ]; then
    echo
    printf '  %sNo stats file found at: %s%s\n' "$C_YELLOW" "$STATS_FILE" "$C_RESET"
    printf '  %sStats are recorded automatically when Claude Code sessions end.%s\n' "$C_GRAY" "$C_RESET"
    pause_continue; return
  fi
  if ! command -v jq >/dev/null 2>&1; then
    printf '  %s[X] jq is required for stats display.%s\n' "$C_RED" "$C_RESET"
    pause_continue; return
  fi

  total=$(wc -l < "$STATS_FILE" | tr -d ' ')
  if [ "$total" -eq 0 ]; then
    printf '  %sStats file exists but contains no entries.%s\n' "$C_YELLOW" "$C_RESET"
    pause_continue; return
  fi

  # Date boundaries
  week_start=$(date -d "last monday" +%Y-%m-%dT00:00:00Z 2>/dev/null || date -v-monday +%Y-%m-%dT00:00:00Z 2>/dev/null || echo "1970-01-01T00:00:00Z")
  month_start=$(date +%Y-%m-01T00:00:00Z)

  draw_border() { printf '  +%s+\n' "$(printf -- '-%.0s' $(seq 1 56))"; }

  draw_header() {
    draw_border
    printf '  | %s%-54s%s |\n' "$C_CYAN" "$1" "$C_RESET"
    draw_border
  }

  draw_row() {
    printf '  | %s%-18s%s %s%-33s%s  |\n' "$C_GRAY" "$1" "$C_RESET" "$C_WHITE" "$2" "$C_RESET"
  }

  show_agg() {
    local label="$1" filter="$2"
    if [ "$filter" = "all" ]; then
      agg=$(jq -s '
        { sessions: length,
          cost: (map(.cost // 0) | add // 0),
          turns: (map(.turns // 0) | add // 0),
          lines_add: (map(.lines_add // 0) | add // 0),
          lines_rm: (map(.lines_rm // 0) | add // 0),
          tok_in: (map(.tok_in // 0) | add // 0),
          tok_out: (map(.tok_out // 0) | add // 0),
          dur_ms: (map(.dur_ms // 0) | add // 0) }' "$STATS_FILE")
    else
      agg=$(jq -s --arg since "$filter" '
        [ .[] | select(.ts >= $since) ] |
        { sessions: length,
          cost: (map(.cost // 0) | add // 0),
          turns: (map(.turns // 0) | add // 0),
          lines_add: (map(.lines_add // 0) | add // 0),
          lines_rm: (map(.lines_rm // 0) | add // 0),
          tok_in: (map(.tok_in // 0) | add // 0),
          tok_out: (map(.tok_out // 0) | add // 0),
          dur_ms: (map(.dur_ms // 0) | add // 0) }' "$STATS_FILE")
    fi

    local sessions cost turns ladd lrm tin tout dur
    sessions=$(echo "$agg" | jq -r '.sessions')
    cost=$(echo "$agg" | jq -r '.cost | . * 10000 | round / 10000')
    turns=$(echo "$agg" | jq -r '.turns')
    ladd=$(echo "$agg" | jq -r '.lines_add')
    lrm=$(echo "$agg" | jq -r '.lines_rm')
    tin=$(echo "$agg" | jq -r '.tok_in')
    tout=$(echo "$agg" | jq -r '.tok_out')
    dur=$(echo "$agg" | jq -r '.dur_ms')

    # Format duration
    local dur_s=$((dur / 1000))
    local dur_str
    if [ "$dur_s" -ge 3600 ]; then
      dur_str="$((dur_s / 3600))h $((dur_s % 3600 / 60))m"
    elif [ "$dur_s" -ge 60 ]; then
      dur_str="$((dur_s / 60))m $((dur_s % 60))s"
    else
      dur_str="${dur_s}s"
    fi

    # Format tokens
    fmt_tok() {
      local n="$1"
      if [ "$n" -ge 1000000 ]; then
        awk "BEGIN{printf \"%.1fM\", $n/1000000}"
      elif [ "$n" -ge 1000 ]; then
        awk "BEGIN{printf \"%.1fK\", $n/1000}"
      else
        echo "$n"
      fi
    }

    draw_header "$label"
    draw_row "Sessions" "$sessions"
    draw_row "Total Cost" "\$$cost"
    draw_row "Total Time" "$dur_str"
    draw_row "Turns" "$turns"
    draw_row "Lines" "+$ladd / -$lrm"
    draw_row "Tokens In" "$(fmt_tok "$tin")"
    draw_row "Tokens Out" "$(fmt_tok "$tout")"
    draw_border
  }

  show_agg "This Week" "$week_start"
  show_agg "This Month" "$month_start"

  # Model usage breakdown
  echo
  draw_header "Model Usage Breakdown"
  jq -s '
    group_by(.model) | map({
      model: .[0].model,
      count: length,
      cost: (map(.cost // 0) | add // 0)
    }) | sort_by(-.count) | .[]' "$STATS_FILE" |
  jq -r --argjson total "$total" '
    "\(.model)\t\(.count)\t\(.count * 100 / $total | . * 10 | round / 10)\t\(.cost | . * 100 | round / 100)"' |
  while IFS=$'\t' read -r model count pct mcost; do
    printf '  | %-28s %4s (%5s%%)  $%-8s  |\n' "$model" "$count" "$pct" "$mcost"
  done
  draw_border

  # Top projects by cost
  echo
  draw_header "Top Projects by Cost"
  jq -s '
    group_by(.project) | map({
      project: .[0].project,
      count: length,
      cost: (map(.cost // 0) | add // 0)
    }) | sort_by(-.cost) | .[:10] | .[]' "$STATS_FILE" |
  jq -r '"\(.project)\t\(.count)\t\(.cost | . * 100 | round / 100)"' |
  while IFS=$'\t' read -r proj count pcost; do
    printf '  | %-30s %4s sessions  $%-8s  |\n' "$proj" "$count" "$pcost"
  done
  draw_border

  # Averages
  echo
  draw_header "Averages (All Time)"
  all_agg=$(jq -s '
    { sessions: length,
      cost: (map(.cost // 0) | add // 0),
      lines: (map((.lines_add // 0) + (.lines_rm // 0)) | add // 0) }' "$STATS_FILE")
  all_sessions=$(echo "$all_agg" | jq -r '.sessions')
  all_cost=$(echo "$all_agg" | jq -r '.cost | . * 10000 | round / 10000')
  all_lines=$(echo "$all_agg" | jq -r '.lines')
  avg_cost_sess=$(awk "BEGIN{if($all_sessions>0) printf \"%.4f\",$all_cost/$all_sessions; else print \"0\"}")
  avg_cost_line=$(awk "BEGIN{if($all_lines>0) printf \"%.4f\",$all_cost/$all_lines; else print \"0\"}")
  printf '  | %s%-20s%s %s%-31s%s  |\n' "$C_GRAY" "Avg Cost/Session" "$C_RESET" "$C_YELLOW" "\$$avg_cost_sess" "$C_RESET"
  printf '  | %s%-20s%s %s%-31s%s  |\n' "$C_GRAY" "Avg Cost/Line" "$C_RESET" "$C_YELLOW" "\$$avg_cost_line" "$C_RESET"
  printf '  | %s%-20s%s %s%-31s%s  |\n' "$C_GRAY" "Total Sessions" "$C_RESET" "$C_YELLOW" "$all_sessions" "$C_RESET"
  printf '  | %s%-20s%s %s%-31s%s  |\n' "$C_GRAY" "Total Cost" "$C_RESET" "$C_YELLOW" "\$$all_cost" "$C_RESET"
  draw_border

  echo
  printf '  %sStats file: %s%s\n' "$C_GRAY" "$STATS_FILE" "$C_RESET"
  pause_continue
}

# ---------------------------------------------------------------------------
# Main menu
# ---------------------------------------------------------------------------
main_menu() {
  while true; do
    banner
    printf '  %sMain Menu%s\n' "$C_CYAN" "$C_RESET"
    printf '  %s%s%s\n' "$C_CYAN" "$(printf -- '-%.0s' {1..30})" "$C_RESET"
    printf '    %s[1]%s Install Claudefy\n' "$C_CYAN" "$C_RESET"
    printf '    %s[2]%s Reset to Default\n' "$C_CYAN" "$C_RESET"
    printf '    %s[3]%s About\n' "$C_CYAN" "$C_RESET"
    printf '    %s[4]%s Stats Dashboard\n' "$C_CYAN" "$C_RESET"
    echo
    printf '    %s[Q]%s Quit\n' "$C_GRAY" "$C_RESET"
    echo
    printf '  Choose an option: '
    read -r choice
    case "$choice" in
      1) do_install ;;
      2) do_reset ;;
      3) do_about ;;
      4) do_stats ;;
      Q|q) printf '\n  Goodbye!\n\n'; exit 0 ;;
      *) printf '  %sInvalid choice.%s\n' "$C_RED" "$C_RESET"; sleep 1 ;;
    esac
  done
}

main_menu
