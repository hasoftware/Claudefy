#!/usr/bin/env bash
# Claudefy statusLine - Linux/bash port
# Outputs a 2- or 3-line Powerline statusLine. Reads JSON from stdin via jq.
# Line 3 (total LOC) only renders if DevRadar is installed (npm install -g @hasoftware/devradar).
#
# Author     : Hoang Anh Dev
# Admin      : HASOFTWARE
# Telegram   : https://t.me/hasoftware
# Repository : https://github.com/hasoftware/Claudefy

set +e
export LANG=en_US.UTF-8
input=$(cat)
[ -z "$input" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

# Optional debug: uncomment to capture input JSON for inspection
# echo "$input" > /tmp/claude-statusline-input.json

# ---------------------------------------------------------------------------
# Extract fields
# ---------------------------------------------------------------------------
get() { echo "$input" | jq -r "$1 // empty" 2>/dev/null; }
geti() { local v; v=$(echo "$input" | jq -r "$1 // 0" 2>/dev/null); echo "${v%.*}"; }

cwd=$(get '.workspace.current_dir')
[ -z "$cwd" ] && cwd=$(get '.cwd')
dir=$(basename "$cwd" 2>/dev/null)
[ -z "$dir" ] && dir='?'

model=$(get '.model.display_name')
[ -z "$model" ] && model='Claude'

ctx=$(get '.context_window.remaining_percentage')
fh=$(get '.rate_limits.five_hour.used_percentage')
fh_reset=$(get '.rate_limits.five_hour.resets_at')
sd=$(get '.rate_limits.seven_day.used_percentage')
sd_reset=$(get '.rate_limits.seven_day.resets_at')
op=$(get '.rate_limits.seven_day_opus.used_percentage')

cost=$(get '.cost.total_cost_usd')
added=$(geti '.cost.total_lines_added')
removed=$(geti '.cost.total_lines_removed')
dur_ms=$(geti '.cost.total_duration_ms')
in_tok=$(geti '.context_window.total_input_tokens')
out_tok=$(geti '.context_window.total_output_tokens')

# ---------------------------------------------------------------------------
# ANSI + Nerd Font icons (UTF-8 byte sequences)
# ---------------------------------------------------------------------------
ESC=$'\033'
NF_FOLDER=$'\xef\x81\xbb'   # U+F07B
NF_GIT=$'\xee\x9c\xa5'      # U+E725
NF_CHIP=$'\xef\x8b\x9b'     # U+F2DB
NF_BRAIN=$'\xef\x81\xae'    # U+F06E
NF_TIMER=$'\xef\x89\x92'    # U+F252
NF_CAL=$'\xef\x81\xb3'      # U+F073
NF_STAR=$'\xef\x80\x85'     # U+F005
NF_HASH=$'\xef\x8a\x92'     # U+F292
NF_USD=$'\xef\x85\x95'      # U+F155
NF_PEN=$'\xef\x81\x80'      # U+F040
NF_CLOCK=$'\xef\x80\x97'    # U+F017
NF_HISTORY=$'\xef\x87\x9a'  # U+F1DA
NF_STASH=$'\xe2\x86\xa9'    # U+21A9
NF_PR=$'\xef\x90\x87'       # U+F407
NF_NODE=$'\xee\x9c\x98'     # U+E718
NF_PYTHON=$'\xee\x88\xb5'   # U+E235
NF_RUST=$'\xee\x9e\xa8'     # U+E7A8
NF_GO=$'\xee\x98\xa6'       # U+E626
NF_DOTNET=$'\xee\x9d\xbf'   # U+E77F
NF_JAVA=$'\xee\x9c\xb8'     # U+E738
NF_RUBY=$'\xee\x9c\xb9'     # U+E739
NF_FLUTTER=$'\xee\x8a\x8e'  # U+E28E
NF_CODE=$'\xef\x84\xa1'     # U+F121 (</> code icon)
NF_CUBE=$'\xef\x86\xb2'     # U+F1B2 (cube — frameworks)
NF_PIE=$'\xef\x88\x80'      # U+F200 (pie-chart — ratio)
NF_ARROW=$'\xee\x82\xb0'    # U+E0B0
DOT_FULL=$'\xe2\x97\x8f'    # U+25CF
DOT_OPEN=$'\xe2\x97\x8b'    # U+25CB
ARROW_UP=$'\xe2\x86\x91'    # U+2191
ARROW_DN=$'\xe2\x86\x93'    # U+2193
ARROW_RT=$'\xe2\x86\x92'    # U+2192
ICON_UP=$'\xe2\xac\x86'     # U+2B06
ICON_WARN=$'\xe2\x9a\xa0'   # U+26A0
ICON_TURNS=$'\xef\x81\xb5'  # U+F075 comment bubble

# ---------------------------------------------------------------------------
# Color helpers
# ---------------------------------------------------------------------------
bg_used() {  # $1 = pct, $2 = good color (default 22)
  local p=${1%.*}; local good=${2:-22}
  if [ "$p" -ge 80 ] 2>/dev/null; then echo 88
  elif [ "$p" -ge 50 ] 2>/dev/null; then echo 130
  else echo "$good"; fi
}
bg_remain() {
  local p=${1%.*}; local good=${2:-22}
  if [ "$p" -le 20 ] 2>/dev/null; then echo 88
  elif [ "$p" -le 50 ] 2>/dev/null; then echo 130
  else echo "$good"; fi
}

# Hanoi time (UTC + 7h) from unix epoch
to_hanoi() {
  local e=$1
  [ -z "$e" ] && return
  local hanoi=$((e + 25200))
  # GNU date (Linux). For macOS use date -u -r.
  date -u -d "@$hanoi" +'%H:%M' 2>/dev/null
}

# Human-readable token count: 1500 -> 1.5k, 1500000 -> 1.5M
human_tokens() {
  local n=$1
  if [ "$n" -ge 1000000 ] 2>/dev/null; then
    awk -v n="$n" 'BEGIN{ printf "%.1fM", n/1000000 }'
  elif [ "$n" -ge 1000 ] 2>/dev/null; then
    awk -v n="$n" 'BEGIN{ printf "%.1fk", n/1000 }'
  else
    echo "$n"
  fi
}

# Round percent to integer
pct_fmt() { local p=$1; printf '%.0f' "$p" 2>/dev/null; }

# ---------------------------------------------------------------------------
# Segment collector
# ---------------------------------------------------------------------------
SEGS_BG=()
SEGS_FG=()
SEGS_TEXT=()
add_seg() { SEGS_BG+=("$1"); SEGS_FG+=("$2"); SEGS_TEXT+=("$3"); }

render_line() {
  # $1/$2/$3 = NAMES of bg/fg/text arrays. No namerefs (local -n needs
  # bash 4.3+) — indirect access via eval for old-bash compatibility.
  local n i bg fg text out="" prev=""
  eval "n=\${#${1}[@]}"
  [ "$n" -eq 0 ] && { echo ""; return; }
  for ((i=0; i<n; i++)); do
    eval "bg=\${${1}[i]}; fg=\${${2}[i]}; text=\${${3}[i]}"
    if [ -n "$prev" ]; then
      out+="${ESC}[38;5;${prev};48;5;${bg}m${NF_ARROW}"
    fi
    out+="${ESC}[48;5;${bg};38;5;${fg}m${text}"
    prev=$bg
  done
  out+="${ESC}[0m${ESC}[38;5;${prev}m${NF_ARROW}${ESC}[0m"
  printf '%s' "$out"
}

# ---------------------------------------------------------------------------
# Compact mode — auto-on over SSH (remote redraws are expensive -> flicker).
# Force with CLAUDEFY_COMPACT=1 (always) or CLAUDEFY_COMPACT=0 (never).
# Compact renders 2 lines and skips gh/curl/devradar/runtime-detect calls.
# ---------------------------------------------------------------------------
COMPACT=${CLAUDEFY_COMPACT:-auto}
if [ "$COMPACT" = "auto" ]; then
  if [ -n "$SSH_CONNECTION" ] || [ -n "$SSH_TTY" ]; then COMPACT=1; else COMPACT=0; fi
fi

# ===========================================================================
# LINE 1: Workspace context
# ===========================================================================
L1_BG=(); L1_FG=(); L1_TEXT=()
add_l1() { L1_BG+=("$1"); L1_FG+=("$2"); L1_TEXT+=("$3"); }

# Folder
add_l1 24 15 " $NF_FOLDER $dir "

# Git + stash/commit/PR
branch=""
if [ -n "$cwd" ] && [ -d "$cwd" ]; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
  [ -z "$branch" ] && branch=$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  if [ -n "$branch" ]; then
    dirty=$(git -C "$cwd" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    ahead=0; behind=0
    rev=$(git -C "$cwd" rev-list --left-right --count "HEAD...@{upstream}" 2>/dev/null)
    if [ -n "$rev" ]; then
      ahead=$(echo "$rev" | awk '{print $1}')
      behind=$(echo "$rev" | awk '{print $2}')
    fi
    gtxt="$NF_GIT $branch"
    if [ "$dirty" -gt 0 ] 2>/dev/null; then
      gtxt+=" $DOT_FULL$dirty"
    else
      gtxt+=" $DOT_OPEN"
    fi
    [ "$ahead"  -gt 0 ] 2>/dev/null && gtxt+=" $ARROW_UP$ahead"
    [ "$behind" -gt 0 ] 2>/dev/null && gtxt+=" $ARROW_DN$behind"
    gbg=28
    [ "$dirty"  -gt 0 ] 2>/dev/null && gbg=130
    [ "$behind" -gt 0 ] 2>/dev/null && gbg=88
    add_l1 "$gbg" 15 " $gtxt "

    # Stash
    stash_count=$(git -C "$cwd" stash list 2>/dev/null | wc -l | tr -d ' ')
    if [ "$stash_count" -gt 0 ] 2>/dev/null; then
      add_l1 53 15 " $NF_STASH $stash_count "
    fi

    # Last commit age
    last_commit=$(git -C "$cwd" log -1 --format=%cr 2>/dev/null)
    if [ -n "$last_commit" ]; then
      short=$(echo "$last_commit" | sed -E \
        -e 's/ ago$//' \
        -e 's/ hours?$/h/' -e 's/ minutes?$/m/' \
        -e 's/ days?$/d/'  -e 's/ weeks?$/w/' \
        -e 's/ months?$/mo/' -e 's/ years?$/y/' \
        -e 's/ seconds?$/s/')
      add_l1 240 15 " $NF_HISTORY $short "
    fi
  fi
fi

# Runtime detection
runtime_icon=""; runtime_name=""
if [ "$COMPACT" != "1" ] && [ -n "$cwd" ] && [ -d "$cwd" ]; then
  if [ -f "$cwd/package.json" ] && command -v node >/dev/null 2>&1; then
    v=$(node --version 2>/dev/null | sed 's/^v//')
    [ -n "$v" ] && runtime_icon=$NF_NODE && runtime_name="Node $v"
  elif { [ -f "$cwd/pyproject.toml" ] || [ -f "$cwd/requirements.txt" ] || [ -f "$cwd/setup.py" ] || [ -f "$cwd/Pipfile" ]; }; then
    if command -v python3 >/dev/null 2>&1; then
      v=$(python3 --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
    elif command -v python >/dev/null 2>&1; then
      v=$(python --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
    fi
    [ -n "$v" ] && runtime_icon=$NF_PYTHON && runtime_name="Py $v"
  elif [ -f "$cwd/Cargo.toml" ] && command -v rustc >/dev/null 2>&1; then
    v=$(rustc --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    [ -n "$v" ] && runtime_icon=$NF_RUST && runtime_name="Rust $v"
  elif [ -f "$cwd/go.mod" ] && command -v go >/dev/null 2>&1; then
    v=$(go version 2>/dev/null | grep -oE 'go[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 | sed 's/^go//')
    [ -n "$v" ] && runtime_icon=$NF_GO && runtime_name="Go $v"
  elif [ -f "$cwd/pubspec.yaml" ] && command -v flutter >/dev/null 2>&1; then
    v=$(flutter --version 2>/dev/null | grep -oE 'Flutter [0-9]+\.[0-9]+\.[0-9]+' | head -1 | awk '{print $2}')
    [ -n "$v" ] && runtime_icon=$NF_FLUTTER && runtime_name="Flutter $v"
  elif command -v dotnet >/dev/null 2>&1 && ls "$cwd"/*.csproj "$cwd"/*.sln 2>/dev/null | head -1 >/dev/null; then
    v=$(dotnet --version 2>/dev/null)
    [ -n "$v" ] && runtime_icon=$NF_DOTNET && runtime_name=".NET $v"
  elif { [ -f "$cwd/pom.xml" ] || [ -f "$cwd/build.gradle" ] || [ -f "$cwd/build.gradle.kts" ]; } && command -v java >/dev/null 2>&1; then
    v=$(java --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    [ -n "$v" ] && runtime_icon=$NF_JAVA && runtime_name="Java $v"
  elif [ -f "$cwd/Gemfile" ] && command -v ruby >/dev/null 2>&1; then
    v=$(ruby --version 2>/dev/null | grep -oE 'ruby [0-9]+\.[0-9]+\.[0-9]+' | awk '{print $2}')
    [ -n "$v" ] && runtime_icon=$NF_RUBY && runtime_name="Ruby $v"
  fi
fi
[ -n "$runtime_name" ] && add_l1 24 15 " $runtime_icon $runtime_name "

# PR + CI status (cached 60s)
if [ "$COMPACT" != "1" ] && [ -n "$branch" ] && command -v gh >/dev/null 2>&1; then
  cache_key=$(echo "${cwd}|${branch}" | tr '/\\:*?"<>|' '_')
  cache_file="/tmp/claude-pr-cache-$cache_key.json"
  pr=""
  if [ -f "$cache_file" ]; then
    ts=$(jq -r '.timestamp // empty' "$cache_file" 2>/dev/null)
    if [ -n "$ts" ]; then
      cache_age=$(( $(date -u +%s) - $(date -u -d "$ts" +%s 2>/dev/null) ))
      if [ "$cache_age" -lt 60 ] 2>/dev/null; then
        pr=$(jq -c '.pr // empty' "$cache_file" 2>/dev/null)
      fi
    fi
  fi
  if [ -z "$pr" ] || [ "$pr" = "null" ]; then
    pr_raw=$(gh pr list --head "$branch" --state open --json number,statusCheckRollup -L 1 2>/dev/null)
    if [ -n "$pr_raw" ]; then
      pr=$(echo "$pr_raw" | jq -c '.[0] // empty')
    fi
    jq -n --argjson p "${pr:-null}" --arg t "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{timestamp:$t, pr:$p}' > "$cache_file"
  fi
  if [ -n "$pr" ] && [ "$pr" != "null" ]; then
    pr_num=$(echo "$pr" | jq -r '.number')
    concl=$(echo "$pr" | jq -r '.statusCheckRollup // [] | map(.conclusion // empty) | join(",")')
    status_icon=$'\xe2\x97\x8b'  # ○
    pr_bg=240
    if echo "$concl" | grep -qE 'FAILURE|CANCELLED|TIMED_OUT'; then
      status_icon=$'\xe2\x9c\x97'  # ✗
      pr_bg=88
    elif echo "$concl" | tr ',' '\n' | grep -qvE 'SUCCESS|NEUTRAL|SKIPPED|^$'; then
      status_icon=$'\xe2\x8c\x9b'  # ⌛
      pr_bg=130
    elif [ -n "$concl" ]; then
      status_icon=$'\xe2\x9c\x93'  # ✓
      pr_bg=22
    fi
    add_l1 "$pr_bg" 15 " $NF_PR #$pr_num $status_icon "
  fi
fi

# Model
add_l1 208 0 " $NF_CHIP $model "

# Clock (Hanoi)
now_hanoi=$(date -u -d "+7 hours" +'%H:%M' 2>/dev/null)
time_str="$now_hanoi ICT"
if [ "$dur_ms" -gt 0 ] 2>/dev/null; then
  total_min=$((dur_ms / 60000))
  h=$((total_min / 60))
  m=$((total_min % 60))
  if [ "$h" -gt 0 ]; then
    time_str="$time_str (${h}h${m}m)"
  else
    time_str="$time_str (${m}m)"
  fi
fi
add_l1 236 15 " $NF_CLOCK $time_str "

# Claudefy update check (cached 24h)
CLAUDEFY_VER='1.3.5'
update_avail=""
uc_file="/tmp/claudefy-update-check.json"
latest_ver=""
need_check=true
if [ -f "$uc_file" ]; then
  uc_ts=$(jq -r '.timestamp // empty' "$uc_file" 2>/dev/null)
  if [ -n "$uc_ts" ]; then
    uc_age=$(( $(date -u +%s) - $(date -u -d "$uc_ts" +%s 2>/dev/null) ))
    if [ "$uc_age" -lt 86400 ] 2>/dev/null && [ "$uc_age" -ge 0 ] 2>/dev/null; then
      need_check=false
      latest_ver=$(jq -r '.latest_version // empty' "$uc_file" 2>/dev/null)
    fi
  fi
fi
if [ "$COMPACT" != "1" ] && $need_check && command -v curl >/dev/null 2>&1; then
  api_resp=$(curl -s --max-time 3 -H 'User-Agent: Claudefy' 'https://api.github.com/repos/hasoftware/Claudefy/releases/latest' 2>/dev/null)
  if [ -n "$api_resp" ]; then
    latest_ver=$(echo "$api_resp" | jq -r '.tag_name // empty' 2>/dev/null | sed 's/^v//')
    if [ -n "$latest_ver" ]; then
      jq -n --arg v "$latest_ver" --arg t "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{timestamp:$t, latest_version:$v}' > "$uc_file" 2>/dev/null
    fi
  fi
fi
ver_gt() {
  local IFS=.; local i; local a=($1) b=($2)
  for ((i=0; i<${#a[@]} || i<${#b[@]}; i++)); do
    local x=${a[i]:-0} y=${b[i]:-0}
    [ "$x" -gt "$y" ] 2>/dev/null && return 0
    [ "$x" -lt "$y" ] 2>/dev/null && return 1
  done
  return 1
}
if [ -n "$latest_ver" ] && ver_gt "$latest_ver" "$CLAUDEFY_VER"; then
  update_avail="$latest_ver"
fi
if [ -n "$update_avail" ]; then
  add_l1 166 15 " $ICON_UP v$update_avail "
fi

# .env safety check (cached 5min)
env_warning=false
if [ "$COMPACT" != "1" ] && [ -n "$cwd" ] && [ -d "$cwd" ]; then
  env_ck=$(echo "$cwd" | tr '/\\:*?"<>|' '_')
  env_cf="/tmp/claudefy-env-$env_ck.txt"
  need_ec=true
  if [ -f "$env_cf" ]; then
    ec_mtime=$(stat -c %Y "$env_cf" 2>/dev/null)
    if [ -n "$ec_mtime" ]; then
      ec_age=$(( $(date -u +%s) - ec_mtime ))
      if [ "$ec_age" -lt 300 ] 2>/dev/null && [ "$ec_age" -ge 0 ] 2>/dev/null; then
        need_ec=false
        [ "$(cat "$env_cf" 2>/dev/null)" = "1" ] && env_warning=true
      fi
    fi
  fi
  if $need_ec; then
    for ef in "$cwd"/.env*; do
      [ -f "$ef" ] || continue
      ign=$(git -C "$cwd" check-ignore "$(basename "$ef")" 2>/dev/null)
      if [ -z "$ign" ]; then env_warning=true; break; fi
    done
    if $env_warning; then echo "1" > "$env_cf"; else echo "0" > "$env_cf"; fi
  fi
fi
if $env_warning; then
  add_l1 88 15 " $ICON_WARN .env "
fi

# ===========================================================================
# LINE 2: Resource usage
# ===========================================================================
L2_BG=(); L2_FG=(); L2_TEXT=()
add_l2() { L2_BG+=("$1"); L2_FG+=("$2"); L2_TEXT+=("$3"); }

if [ -n "$ctx" ]; then
  bg=$(bg_remain "$ctx" 29)
  add_l2 "$bg" 15 " $NF_BRAIN Context: $(pct_fmt "$ctx")% "
fi
if [ -n "$fh" ]; then
  bg=$(bg_used "$fh" 22)
  txt=" $NF_TIMER 5h: $(pct_fmt "$fh")%"
  reset_t=$(to_hanoi "$fh_reset")
  [ -n "$reset_t" ] && txt+=" $ARROW_RT$reset_t"
  txt+=" "
  add_l2 "$bg" 15 "$txt"
fi
sd_label="7d"
if [ -n "$sd_reset" ]; then
  now_unix=$(date -u +%s)
  rem_sec=$((sd_reset - now_unix))
  rem_days=$(( (rem_sec + 86399) / 86400 ))
  if [ "$rem_days" -ge 1 ] 2>/dev/null && [ "$rem_days" -le 7 ] 2>/dev/null; then
    sd_label="${rem_days}d"
  fi
fi
if [ -n "$sd" ]; then
  bg=$(bg_used "$sd" 28)
  add_l2 "$bg" 15 " $NF_CAL $sd_label: $(pct_fmt "$sd")% "
fi
if [ -n "$op" ]; then
  bg=$(bg_used "$op" 65)
  add_l2 "$bg" 15 " $NF_STAR Opus $sd_label: $(pct_fmt "$op")% "
fi
# Smart Model Hint — suggest switching to Sonnet when Opus quota is high
op_hint=""
if [ -n "$op" ]; then
  op_hint=$op
else
  model_id=$(get '.model.id')
  if echo "$model_id" | grep -qi 'opus'; then
    [ -n "$sd" ] && op_hint=$sd
  fi
fi
if [ -n "$op_hint" ]; then
  op_hint_int=${op_hint%.*}
  if [ "$op_hint_int" -ge 80 ] 2>/dev/null; then
    add_l2 88 15 " ${ARROW_RT}Sonnet! "
  elif [ "$op_hint_int" -ge 60 ] 2>/dev/null; then
    add_l2 58 15 " ${ARROW_RT}Sonnet? "
  fi
fi
if [ -n "$cost" ]; then
  add_l2 94 15 " $NF_USD \$$(printf '%.2f' "$cost") "
fi
if [ "$added" -gt 0 ] 2>/dev/null || [ "$removed" -gt 0 ] 2>/dev/null; then
  add_l2 22 15 " $NF_PEN +$added -$removed "
fi
total_tok=$((in_tok + out_tok))
if [ "$total_tok" -gt 0 ] 2>/dev/null; then
  add_l2 24 15 " $NF_HASH $(human_tokens $total_tok) "
fi

# Turns (from transcript)
tp=$(get '.transcript_path')
if [ -n "$tp" ] && [ -f "$tp" ]; then
  turns=$(grep -c '"type":"user"' "$tp" 2>/dev/null)
  if [ "$turns" -gt 0 ] 2>/dev/null; then
    add_l2 24 15 " $ICON_TURNS $turns turns "
  fi
fi

# ===========================================================================
# LINE 3: Project DNA (DevRadar — cached by git HEAD, TTL 10min)
# ===========================================================================
L3_BG=(); L3_FG=(); L3_TEXT=()
add_l3() { L3_BG+=("$1"); L3_FG+=("$2"); L3_TEXT+=("$3"); }

if [ "$COMPACT" != "1" ] && [ -n "$cwd" ] && [ -d "$cwd" ] && command -v devradar >/dev/null 2>&1; then
  head_sha=$(git -C "$cwd" rev-parse HEAD 2>/dev/null)
  cache_key_raw="${cwd}|${head_sha}"
  dr_cache_key=$(echo "$cache_key_raw" | tr '/\\:*?"<>|' '_')
  dr_cache_file="/tmp/claude-devradar-cache-$dr_cache_key.json"

  dr_data=""
  if [ -f "$dr_cache_file" ]; then
    ts=$(jq -r '.timestamp // empty' "$dr_cache_file" 2>/dev/null)
    if [ -n "$ts" ]; then
      cache_age=$(( $(date -u +%s) - $(date -u -d "$ts" +%s 2>/dev/null) ))
      if [ "$cache_age" -lt 600 ] 2>/dev/null && [ "$cache_age" -ge 0 ] 2>/dev/null; then
        dr_data=$(jq -c '.data // empty' "$dr_cache_file" 2>/dev/null)
      fi
    fi
  fi
  if [ -z "$dr_data" ] || [ "$dr_data" = "null" ]; then
    dr_json=$(devradar --format json "$cwd" 2>/dev/null)
    if [ -n "$dr_json" ]; then
      dr_data=$(echo "$dr_json" | jq -c '.' 2>/dev/null)
      if [ -n "$dr_data" ]; then
        jq -n --argjson d "$dr_data" --arg t "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{timestamp:$t, data:$d}' > "$dr_cache_file" 2>/dev/null
      fi
    fi
  fi
  if [ -n "$dr_data" ] && [ "$dr_data" != "null" ]; then
    code_lines=$(echo "$dr_data" | jq -r '.summary.codeLines // 0' 2>/dev/null)
    if [ "$code_lines" -gt 0 ] 2>/dev/null; then
      fw_list=$(echo "$dr_data" | jq -r '.technologies.frameworks // [] | join("·")' 2>/dev/null)
      [ -n "$fw_list" ] && add_l3 60 15 " $NF_CUBE $fw_list "

      loc_str=$(human_tokens "$code_lines")
      add_l3 23 15 " $NF_CODE $loc_str Lines "

      total_lines=$(echo "$dr_data" | jq -r '.summary.totalLines // 0' 2>/dev/null)
      if [ "$total_lines" -gt 0 ] 2>/dev/null; then
        ratio=$(awk -v c="$code_lines" -v t="$total_lines" 'BEGIN{ printf "%.0f", (c/t)*100 }')
        add_l3 25 15 " $NF_PIE $ratio% code "
      fi
    fi
  fi
fi

# ===========================================================================
# LINE 4: Branding
# ===========================================================================
L4_BG=(); L4_FG=(); L4_TEXT=()
add_l4() { L4_BG+=("$1"); L4_FG+=("$2"); L4_TEXT+=("$3"); }

add_l4 237 75 " Claudefy v$CLAUDEFY_VER "
add_l4 237 208 " Author: HoangAnhDev "

# ===========================================================================
# Output
# ===========================================================================
line1=$(render_line L1_BG L1_FG L1_TEXT)
line2=$(render_line L2_BG L2_FG L2_TEXT)
line4=$(render_line L4_BG L4_FG L4_TEXT)
if [ "$COMPACT" = "1" ]; then
  printf '%s\n%s' "$line1" "$line2"
elif [ "${#L3_BG[@]}" -gt 0 ]; then
  line3=$(render_line L3_BG L3_FG L3_TEXT)
  printf '%s\n%s\n%s\n%s' "$line1" "$line2" "$line3" "$line4"
else
  printf '%s\n%s\n%s' "$line1" "$line2" "$line4"
fi
