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
# Single jq pass — one subprocess instead of ~16. Each render used to spawn
# jq per field; over SSH that latency was the main source of flicker.
eval "$(echo "$input" | jq -r '
  def s(f): (f // "") | tostring;
  @sh "cwd=\(s(.workspace.current_dir // .cwd))",
  @sh "model=\(s(.model.display_name))",
  @sh "model_id=\(s(.model.id))",
  @sh "ctx=\(s(.context_window.remaining_percentage))",
  @sh "fh=\(s(.rate_limits.five_hour.used_percentage))",
  @sh "fh_reset=\(s(.rate_limits.five_hour.resets_at))",
  @sh "sd=\(s(.rate_limits.seven_day.used_percentage))",
  @sh "sd_reset=\(s(.rate_limits.seven_day.resets_at))",
  @sh "op=\(s(.rate_limits.seven_day_opus.used_percentage))",
  @sh "cost=\(s(.cost.total_cost_usd))",
  @sh "added=\(s(.cost.total_lines_added // 0))",
  @sh "removed=\(s(.cost.total_lines_removed // 0))",
  @sh "dur_ms=\(s(.cost.total_duration_ms // 0))",
  @sh "in_tok=\(s(.context_window.total_input_tokens // 0))",
  @sh "out_tok=\(s(.context_window.total_output_tokens // 0))",
  @sh "session_id=\(s(.session_id))",
  @sh "perm=\(s(.permission_mode // .permissionMode))",
  @sh "tp=\(s(.transcript_path))"
' 2>/dev/null)"

[ -z "$model" ] && model='Claude'
dir=$(basename "$cwd" 2>/dev/null)
[ -z "$dir" ] && dir='?'
# integer floors (former geti behavior)
added=${added%.*}; removed=${removed%.*}; dur_ms=${dur_ms%.*}
in_tok=${in_tok%.*}; out_tok=${out_tok%.*}

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
NF_BATT=$'\xef\x89\x80'     # U+F240 battery
NF_DOCKER=$'\xef\x8c\x88'   # U+F308 docker whale
NF_GLOBE=$'\xef\x82\xac'    # U+F0AC globe
NF_SEARCH=$'\xef\x80\x82'   # U+F002 magnifier
NF_MOON=$'\xef\x86\x86'     # U+F186 moon (idle)
NF_TROPHY=$'\xef\x82\x91'   # U+F091 trophy
NF_BOMB=$'\xef\x87\xa2'     # U+F1E2 bomb (merge conflicts)
NF_CPU=$'\xef\x83\xa4'      # U+F0E4 tachometer (CPU load)
NF_RAM=$'\xef\x88\xb3'      # U+F233 server (RAM usage)
ICON_RECYCLE=$'\xe2\x99\xbb'   # U+267B recycle (compact count)
ICON_HOURGLASS=$'\xe2\x8c\x9b' # U+231B hourglass
ICON_SIGMA=$'\xce\xa3'         # U+03A3 sigma

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

# Seconds since a file's mtime; prints nothing if the file is missing
file_age() {
  local m
  m=$(stat -c %Y "$1" 2>/dev/null)
  [ -z "$m" ] && return 1
  echo $(( $(date -u +%s) - m ))
}

# Raw mtime — for cache keys, where file_age would change every second
file_mtime() { stat -c %Y "$1" 2>/dev/null; }

# git's own thresholds for %cr (90s / 90min / 36h / 14d / 8w / 12mo), so a
# locally formatted age reads exactly as git would have written it
rel_age() {
  local a=$1
  [ "$a" -lt 0 ] 2>/dev/null && a=0
  if   [ "$a" -lt 90 ];       then echo "${a}s"
  elif [ "$a" -lt 5400 ];     then echo "$(( (a + 30) / 60 ))m"
  elif [ "$a" -lt 129600 ];   then echo "$(( (a + 1800) / 3600 ))h"
  elif [ "$a" -lt 1209600 ];  then echo "$(( (a + 43200) / 86400 ))d"
  elif [ "$a" -lt 4838400 ];  then echo "$(( (a + 302400) / 604800 ))w"
  elif [ "$a" -lt 31556952 ]; then echo "$(( (a + 1314873) / 2629746 ))mo"
  else echo "$(( (a + 15778476) / 31556952 ))y"
  fi
}

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

# ---------------------------------------------------------------------------
# SYSTEM: CPU / RAM usage. TTL is deliberately *below* the statusLine
# refreshInterval (10s): the cache file's mtime is stamped partway through a
# run, so by the next tick its age reads a hair under 10s — an equal TTL would
# hit the cache every time and the numbers would never move.
# Computed *before* the render cache so its key can include these values —
# otherwise a load change alone hits that cache and the numbers look frozen.
# Always run, even in compact mode: seeing load on the box you just SSH'd into
# is the whole point, and reading /proc costs nothing.
# ---------------------------------------------------------------------------
SYS_BG=(); SYS_FG=(); SYS_TEXT=()
add_sys() { SYS_BG+=("$1"); SYS_FG+=("$2"); SYS_TEXT+=("$3"); }

sys_cf="/tmp/claudefy-sysstat.txt"
sys_age=$(file_age "$sys_cf")
if [ -z "$sys_age" ] || [ "$sys_age" -ge 8 ] 2>/dev/null; then
  prev_idle=0; prev_total=0; had_prev=0
  if [ -f "$sys_cf" ]; then
    read -r prev_idle prev_total _ _ < "$sys_cf" 2>/dev/null
    [ -n "$prev_total" ] && [ "$prev_total" -gt 0 ] 2>/dev/null && had_prev=1
  fi
  cur_idle=0; cur_total=0; new_cpu_pct=""
  if [ -r /proc/stat ]; then
    read -r _ cpu_user cpu_nice cpu_system cpu_idle cpu_iowait cpu_irq cpu_softirq cpu_steal _ < /proc/stat
    cur_idle=$((cpu_idle + cpu_iowait))
    cur_total=$((cpu_user + cpu_nice + cpu_system + cpu_idle + cpu_iowait + cpu_irq + cpu_softirq + cpu_steal))
    if [ "$had_prev" -eq 1 ]; then
      d_idle=$((cur_idle - prev_idle)); d_total=$((cur_total - prev_total))
      [ "$d_total" -gt 0 ] 2>/dev/null && new_cpu_pct=$(( 100 - (d_idle * 100 / d_total) ))
    fi
  fi
  new_ram_pct=""
  if [ -r /proc/meminfo ]; then
    mem_total=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
    mem_avail=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
    if [ -n "$mem_total" ] && [ -n "$mem_avail" ] && [ "$mem_total" -gt 0 ] 2>/dev/null; then
      new_ram_pct=$(( (mem_total - mem_avail) * 100 / mem_total ))
    fi
  fi
  printf '%s %s %s %s\n' "$cur_idle" "$cur_total" "$new_cpu_pct" "$new_ram_pct" > "$sys_cf"
fi
cpu_pct=""; ram_pct=""
[ -f "$sys_cf" ] && read -r _ _ cpu_pct ram_pct < "$sys_cf" 2>/dev/null
if [ -n "$cpu_pct" ]; then
  sys_bg=$(bg_used "$cpu_pct" 22)
  add_sys "$sys_bg" 15 " $NF_CPU CPU:${cpu_pct}% "
fi
if [ -n "$ram_pct" ]; then
  sys_bg=$(bg_used "$ram_pct" 24)
  add_sys "$sys_bg" 15 " $NF_RAM RAM:${ram_pct}% "
fi

# ---------------------------------------------------------------------------
# Render cache — when the values we display are unchanged, reuse the last
# render verbatim (TTL 10s). Identical output lets the host UI diff to a
# no-op instead of repainting, which keeps full mode smooth even over SSH.
# ---------------------------------------------------------------------------
tok_h=$(human_tokens $((in_tok + out_tok)))
rc_key="$COMPACT|$cwd|$model|$perm|${ctx%.*}|${fh%.*}|${sd%.*}|${op%.*}|$cost|$added|$removed|$((dur_ms / 60000))|$tok_h|$cpu_pct|$ram_pct|$(date -u +%H:%M)"
rc_file="/tmp/claudefy-render-${session_id:-nosession}.txt"
if [ -f "$rc_file" ]; then
  rc_age=$(file_age "$rc_file")
  if [ -n "$rc_age" ] && [ "$rc_age" -le 10 ] 2>/dev/null; then
    if [ "$(head -n 1 "$rc_file" 2>/dev/null)" = "$rc_key" ]; then
      tail -n +2 "$rc_file"
      exit 0
    fi
  fi
fi

# ===========================================================================
# LINE 1: Workspace context
# ===========================================================================
L1_BG=(); L1_FG=(); L1_TEXT=()
add_l1() { L1_BG+=("$1"); L1_FG+=("$2"); L1_TEXT+=("$3"); }

# Folder
add_l1 24 15 " $NF_FOLDER $dir "

# Git + stash/commit/PR.
# A render used to spawn six git processes: symbolic-ref, rev-parse, status,
# rev-list, stash list and log. `status --porcelain=v2 --branch` answers the
# first four in one pass, and the last two only move when HEAD or the stash log
# does, so they hang off a cache keyed on the HEAD commit. Steady state: one
# git process per render. The values are read through a here-doc rather than
# eval — branch names may legally contain ';' and '$'.
branch=""
head_oid=""
if [ -n "$cwd" ] && [ -d "$cwd" ]; then
  dirty=0; ahead=0; behind=0; head_name=""
  gst=$(git -C "$cwd" status --porcelain=v2 --branch 2>/dev/null)
  if [ -n "$gst" ]; then
    gvals=$(printf '%s\n' "$gst" | awk '
      /^# branch\.oid /  { oid  = $3 }
      /^# branch\.head / { hd   = $3 }
      /^# branch\.ab /   { a = $3; b = $4 }
      !/^#/              { d++ }
      END {
        gsub(/^\+/, "", a); gsub(/^-/, "", b)
        print (oid == "" ? "-" : oid)
        print (hd  == "" ? "-" : hd)
        print a + 0; print b + 0; print d + 0
      }')
    { read -r head_oid; read -r head_name; read -r ahead; read -r behind; read -r dirty; } <<EOF
$gvals
EOF
    [ "$head_oid" = "-" ] && head_oid=""
    if [ -n "$head_name" ] && [ "$head_name" != "-" ] && [ "$head_name" != "(detached)" ]; then
      branch=$head_name
    elif [ -n "$head_oid" ] && [ "$head_oid" != "(initial)" ]; then
      branch=$(printf '%s' "$head_oid" | cut -c1-7)
    fi
  fi
  if [ -n "$branch" ]; then
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
    # Widget: editing directly on main/master -> red alert
    case "$branch" in
      main|master) [ "$dirty" -gt 0 ] 2>/dev/null && gbg=88 ;;
    esac
    add_l1 "$gbg" 15 " $gtxt "

    # Stash count and commit time only move when HEAD or the stash log moves.
    # Key on both and these two spawns vanish on every unchanged render. The
    # commit is kept as a unix timestamp rather than git's relative wording, so
    # the label still ticks between refreshes and no longer depends on git
    # printing English.
    gkey="$head_oid"
    stash_log="$cwd/.git/logs/refs/stash"
    if [ -f "$stash_log" ]; then
      gkey="$gkey-$(file_mtime "$stash_log")"
    fi
    gc_ck=$(echo "$cwd" | tr '/\\:*?"<>|' '_')
    gc_cf="/tmp/claudefy-git-$gc_ck.txt"
    stash_count=0; commit_unix=0; gc_hit=0
    if [ -f "$gc_cf" ]; then
      read -r c_key c_stash c_ct < "$gc_cf" 2>/dev/null
      if [ -n "$c_key" ] && [ "$c_key" = "$gkey" ]; then
        stash_count=${c_stash:-0}; commit_unix=${c_ct:-0}; gc_hit=1
      fi
    fi
    if [ "$gc_hit" != "1" ]; then
      stash_count=$(git -C "$cwd" stash list 2>/dev/null | wc -l | tr -d ' ')
      commit_unix=$(git -C "$cwd" log -1 --format=%ct 2>/dev/null)
      [ -z "$commit_unix" ] && commit_unix=0
      echo "$gkey $stash_count $commit_unix" > "$gc_cf"
    fi

    if [ "$stash_count" -gt 0 ] 2>/dev/null; then
      add_l1 53 15 " $NF_STASH $stash_count "
    fi

    if [ "$commit_unix" -gt 0 ] 2>/dev/null; then
      add_l1 240 15 " $NF_HISTORY $(rel_age $(( $(date -u +%s) - commit_unix ))) "
    fi
  fi
fi

# Runtime detection
runtime_icon=""; runtime_name=""
runtime_txt=""; rt_done=0
if [ "$COMPACT" != "1" ] && [ -n "$cwd" ]; then
  rt_ck=$(echo "$cwd" | tr '/\\:*?"<>|' '_')
  rt_cf="/tmp/claudefy-runtime-$rt_ck.txt"
  rt_age=$(file_age "$rt_cf")
  if [ -n "$rt_age" ] && [ "$rt_age" -le 60 ] 2>/dev/null; then
    runtime_txt=$(cat "$rt_cf" 2>/dev/null)
    rt_done=1
  fi
fi
if [ "$rt_done" != "1" ] && [ "$COMPACT" != "1" ] && [ -n "$cwd" ] && [ -d "$cwd" ]; then
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
if [ "$rt_done" != "1" ]; then
  [ -n "$runtime_name" ] && runtime_txt=" $runtime_icon $runtime_name "
  [ -n "$rt_cf" ] && printf '%s' "$runtime_txt" > "$rt_cf" 2>/dev/null
fi
[ -n "$runtime_txt" ] && add_l1 24 15 "$runtime_txt"

# PR + CI status (cached 60s)
if [ "$COMPACT" != "1" ] && [ -n "$branch" ] && command -v gh >/dev/null 2>&1; then
  cache_key=$(echo "${cwd}|${branch}" | tr '/\\:*?"<>|' '_')
  cache_file="/tmp/claude-pr-cache-$cache_key.json"
  # Freshness is tracked separately from the payload on purpose. Testing the
  # payload alone cannot tell "cache expired" from "cache says there is no open
  # PR" — so on any branch without a PR, the common case, this re-ran `gh pr
  # list` on every single render, network round trip and all.
  pr=""
  pr_fresh=0
  if [ -f "$cache_file" ]; then
    ts=$(jq -r '.timestamp // empty' "$cache_file" 2>/dev/null)
    if [ -n "$ts" ]; then
      cache_age=$(( $(date -u +%s) - $(date -u -d "$ts" +%s 2>/dev/null) ))
      if [ "$cache_age" -lt 60 ] 2>/dev/null && [ "$cache_age" -ge 0 ] 2>/dev/null; then
        pr=$(jq -c '.pr // empty' "$cache_file" 2>/dev/null)
        pr_fresh=1
      fi
    fi
  fi
  if [ "$pr_fresh" != "1" ]; then
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

# Widget: battery (laptops — shown when discharging or low)
if [ "$COMPACT" != "1" ]; then
  batt_dir=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1)
  if [ -n "$batt_dir" ] && [ -f "$batt_dir/capacity" ]; then
    batt_pct=$(cat "$batt_dir/capacity" 2>/dev/null)
    batt_state=$(cat "$batt_dir/status" 2>/dev/null | tr 'A-Z' 'a-z')
    if [ -n "$batt_pct" ] && { [ "$batt_state" = "discharging" ] || [ "$batt_pct" -le 30 ] 2>/dev/null; }; then
      bb=240
      [ "$batt_pct" -le 50 ] 2>/dev/null && bb=130
      [ "$batt_pct" -le 20 ] 2>/dev/null && bb=88
      add_l1 "$bb" 15 " $NF_BATT $batt_pct% "
    fi
  fi
fi

# Widget: running Docker containers (cached 60s)
if [ "$COMPACT" != "1" ] && command -v docker >/dev/null 2>&1; then
  dk_cf="/tmp/claudefy-docker.txt"
  dk_age=$(file_age "$dk_cf")
  if [ -z "$dk_age" ] || [ "$dk_age" -ge 60 ] 2>/dev/null; then
    docker ps -q 2>/dev/null | wc -l | tr -d ' ' > "$dk_cf"
  fi
  dk_n=$(cat "$dk_cf" 2>/dev/null)
  if [ "$dk_n" -gt 0 ] 2>/dev/null; then
    add_l1 25 15 " $NF_DOCKER $dk_n "
  fi
fi

# Widget: dev server alive on a common port (probe via /dev/tcp, cached 30s).
# A dev server doesn't come and go between two renders; 30s notices it soon
# enough without paying for five connect attempts every time.
if [ "$COMPACT" != "1" ]; then
  sp_cf="/tmp/claudefy-devport.txt"
  sp_age=$(file_age "$sp_cf")
  if [ -z "$sp_age" ] || [ "$sp_age" -ge 30 ] 2>/dev/null; then
    srv_port=""
    for p in 3000 5173 8080 4200 8000; do
      if (echo >"/dev/tcp/127.0.0.1/$p") 2>/dev/null; then srv_port=$p; break; fi
    done
    echo "$srv_port" > "$sp_cf"
  fi
  srv_port=$(cat "$sp_cf" 2>/dev/null)
  [ -n "$srv_port" ] && add_l1 29 15 " $NF_GLOBE :$srv_port "
fi

# Widget: permission mode — safety cue, shown even in compact mode
if [ -n "$perm" ]; then
  case "$perm" in
    bypassPermissions) add_l1 88 15 " $ICON_WARN YOLO " ;;
    plan)              add_l1 61 15 " $NF_PEN Plan " ;;
    acceptEdits)       add_l1 130 0  " $NF_PEN AutoEdit " ;;
  esac
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
CLAUDEFY_VER='1.5.1'
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
  fh_int=${fh%.*}
  txt=" $NF_TIMER 5h: $(pct_fmt "$fh")%"
  if [ -n "$fh_reset" ]; then
    now_s=$(date -u +%s)
    rem_s=$((fh_reset - now_s))
    if [ "$rem_s" -gt 0 ] 2>/dev/null && [ "$rem_s" -le 18000 ] 2>/dev/null; then
      # Widget: quota pace — burning faster than the 5h window elapses
      elapsed_pct=$(( (18000 - rem_s) * 100 / 18000 ))
      if [ "$fh_int" -gt $((elapsed_pct + 15)) ] 2>/dev/null; then
        [ "$bg" = "22" ] && bg=130
        txt+="$ARROW_UP"
      fi
      # Widget: countdown to reset once quota is high
      if [ "$fh_int" -ge 70 ] 2>/dev/null; then
        txt+=" (-$((rem_s / 60))m)"
      fi
    fi
  fi
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
  cost_txt=" $NF_USD \$$(printf '%.2f' "$cost")"
  # Widget: burn rate $/h (needs >5 min of session for a stable number)
  if [ "$dur_ms" -gt 300000 ] 2>/dev/null && awk -v c="$cost" 'BEGIN{ exit !(c > 0) }' 2>/dev/null; then
    rate=$(awk -v c="$cost" -v d="$dur_ms" 'BEGIN{ if (d > 0) printf "%.1f", c * 3600000 / d }')
    [ -n "$rate" ] && cost_txt+=" (\$$rate/h)"
  fi
  add_l2 94 15 "$cost_txt "
fi
if [ "$added" -gt 0 ] 2>/dev/null || [ "$removed" -gt 0 ] 2>/dev/null; then
  add_l2 22 15 " $NF_PEN +$added -$removed "
fi
total_tok=$((in_tok + out_tok))
if [ "$total_tok" -gt 0 ] 2>/dev/null; then
  add_l2 24 15 " $NF_HASH $(human_tokens $total_tok) "
fi

# Turns (from transcript) + session widgets that need the transcript.
# These scans read the whole file and were the bulk of a render. None of them
# can change unless the transcript does, so they share one cache keyed on its
# size and mtime. While the session sits idle — exactly when refreshInterval
# fires — this collapses to a single stat(). COMPACT is part of the key because
# it decides whether the extra scans run at all.
if [ -n "$tp" ] && [ -f "$tp" ]; then
  tp_key="$COMPACT-$(wc -c < "$tp" 2>/dev/null | tr -d ' ')-$(file_mtime "$tp")"
  tx_cf="/tmp/claudefy-tx-${session_id:-nosession}.txt"
  turns=0; build_n=0; explore_n=0; cpt=0; tx_hit=0
  if [ -f "$tx_cf" ]; then
    read -r k_key k_turns k_build k_explore k_cpt < "$tx_cf" 2>/dev/null
    if [ -n "$k_key" ] && [ "$k_key" = "$tp_key" ]; then
      turns=${k_turns:-0}; build_n=${k_build:-0}; explore_n=${k_explore:-0}; cpt=${k_cpt:-0}
      tx_hit=1
    fi
  fi
  if [ "$tx_hit" != "1" ]; then
    turns=$(grep -c '"type":"user"' "$tp" 2>/dev/null)
    [ -z "$turns" ] && turns=0
    if [ "$COMPACT" != "1" ]; then
      cpt=$(grep -c 'compact_boundary' "$tp" 2>/dev/null)
      [ -z "$cpt" ] && cpt=0
      recent=$(tail -c 150000 "$tp" 2>/dev/null)
      build_n=$(printf '%s' "$recent" | grep -oE '"name":"(Edit|Write|NotebookEdit)"' | wc -l | tr -d ' ')
      explore_n=$(printf '%s' "$recent" | grep -oE '"name":"(Read|Grep|Glob)"' | wc -l | tr -d ' ')
    fi
    echo "$tp_key $turns $build_n $explore_n $cpt" > "$tx_cf"
  fi

  if [ "$turns" -gt 0 ] 2>/dev/null; then
    turns_txt=" $ICON_TURNS $turns turns"
    # Widget: session velocity (turns/hour, needs >10 min)
    if [ "$dur_ms" -gt 600000 ] 2>/dev/null; then
      turns_txt+=" ($(( turns * 3600000 / dur_ms ))/h)"
    fi
    add_l2 24 15 "$turns_txt "

    # Widget: auto-compact forecast — per-session context burn rate.
    # First render stores (turns, ctx); later renders extrapolate to ~10% left.
    if [ "$COMPACT" != "1" ] && [ -n "$ctx" ] && [ -n "$session_id" ]; then
      ctx_int=${ctx%.*}
      fc_cf="/tmp/claudefy-ctx-$session_id.txt"
      if [ ! -f "$fc_cf" ]; then
        echo "$turns $ctx_int" > "$fc_cf"
      else
        read t0 c0 < "$fc_cf"
        fc_dt=$((turns - t0)); fc_dc=$((c0 - ctx_int))
        if [ "$fc_dt" -ge 3 ] 2>/dev/null && [ "$fc_dc" -gt 0 ] 2>/dev/null && [ "$ctx_int" -le 60 ] 2>/dev/null; then
          fc_left=$(( (ctx_int - 10) * fc_dt / fc_dc ))
          if [ "$fc_left" -ge 0 ] && [ "$fc_left" -le 30 ]; then
            fb=130; [ "$fc_left" -le 5 ] && fb=88
            add_l2 "$fb" 15 " $ICON_HOURGLASS ~${fc_left} turns${ARROW_RT}compact "
          fi
        fi
      fi
    fi
  fi

  if [ "$COMPACT" != "1" ]; then
    # Widget: session phase — exploring vs building, from recent tool calls
    if [ $((build_n + explore_n)) -ge 5 ] 2>/dev/null; then
      if [ "$build_n" -ge "$explore_n" ] 2>/dev/null; then
        add_l2 22 15 " $NF_PEN build "
      else
        add_l2 24 15 " $NF_SEARCH explore "
      fi
    fi

    # Widget: compact count — how many times this session lost its memory
    [ "$cpt" -gt 0 ] 2>/dev/null && add_l2 58 15 " $ICON_RECYCLE ${cpt}x "

    # Widget: idle time since the transcript was last written
    tp_age=$(file_age "$tp")
    if [ -n "$tp_age" ] && [ "$tp_age" -ge 600 ] 2>/dev/null; then
      add_l2 240 15 " $NF_MOON idle $((tp_age / 60))m "
    fi
  fi
fi

# ===========================================================================
# LINE 3: Project DNA (DevRadar — cached by git HEAD, TTL 10min)
# ===========================================================================
L3_BG=(); L3_FG=(); L3_TEXT=()
add_l3() { L3_BG+=("$1"); L3_FG+=("$2"); L3_TEXT+=("$3"); }

# --- Git health widgets: uncommitted pile, branch age, conflict radar ------
if [ "$COMPACT" != "1" ] && [ -n "$branch" ]; then
  # Widget: big uncommitted pile — AI writes fast, commit before you drown
  if [ "$dirty" -gt 0 ] 2>/dev/null; then
    ucl=$( { git -C "$cwd" diff --numstat 2>/dev/null; git -C "$cwd" diff --cached --numstat 2>/dev/null; } \
          | awk '{s += $1 + $2} END {print s + 0}')
    if [ "$ucl" -ge 300 ] 2>/dev/null; then
      ub=130; [ "$ucl" -ge 800 ] 2>/dev/null && ub=88
      add_l3 "$ub" 15 " $ICON_WARN $ucl uncommitted "
    fi
  fi

  # Branch age vs main + conflict radar (cached 5 min per cwd|branch)
  main_ref=""
  if [ "$branch" != "main" ] && [ "$branch" != "master" ]; then
    if git -C "$cwd" show-ref --verify --quiet refs/heads/main 2>/dev/null; then main_ref=main
    elif git -C "$cwd" show-ref --verify --quiet refs/heads/master 2>/dev/null; then main_ref=master; fi
  fi
  if [ -n "$main_ref" ]; then
    gh_ck=$(echo "${cwd}|${branch}" | tr '/\\:*?"<>|' '_')
    gh_cf="/tmp/claudefy-githealth-$gh_ck.txt"
    gh_age=$(file_age "$gh_cf")
    if [ -z "$gh_age" ] || [ "$gh_age" -ge 300 ] 2>/dev/null; then
      b_age=0; b_behind=0; b_conf=0
      base=$(git -C "$cwd" merge-base HEAD "$main_ref" 2>/dev/null)
      if [ -n "$base" ]; then
        base_ts=$(git -C "$cwd" show -s --format=%ct "$base" 2>/dev/null)
        [ -n "$base_ts" ] && b_age=$(( ( $(date -u +%s) - base_ts ) / 86400 ))
        b_behind=$(git -C "$cwd" rev-list --count "HEAD..$main_ref" 2>/dev/null)
        # Conflict radar: merge-tree exits 1 iff the merge would conflict (git >= 2.38)
        git -C "$cwd" merge-tree --write-tree HEAD "$main_ref" >/dev/null 2>&1
        [ $? -eq 1 ] && b_conf=1
      fi
      echo "$b_age ${b_behind:-0} $b_conf" > "$gh_cf"
    fi
    read b_age b_behind b_conf < "$gh_cf"
    if [ "$b_age" -ge 3 ] 2>/dev/null || [ "$b_behind" -ge 10 ] 2>/dev/null; then
      add_l3 64 15 " $NF_GIT ${b_age}d $ARROW_DN$b_behind "
    fi
    [ "$b_conf" = "1" ] && add_l3 88 15 " $NF_BOMB merge conflicts "
  fi
fi

if [ "$COMPACT" != "1" ] && [ -n "$cwd" ] && [ -d "$cwd" ] && command -v devradar >/dev/null 2>&1; then
  # head_oid already came back with the porcelain status — no second rev-parse.
  cache_key_raw="${cwd}|${head_oid}"
  dr_cache_key=$(echo "$cache_key_raw" | tr '/\\:*?"<>|' '_')
  dr_cache_file="/tmp/claude-devradar-cache-$dr_cache_key.json"

  # Same split as the PR cache: an empty payload is a legitimate cached answer,
  # not a miss. Without the flag a repo devradar can't parse re-ran a full scan
  # on every render.
  dr_data=""
  dr_fresh=0
  if [ -f "$dr_cache_file" ]; then
    ts=$(jq -r '.timestamp // empty' "$dr_cache_file" 2>/dev/null)
    if [ -n "$ts" ]; then
      cache_age=$(( $(date -u +%s) - $(date -u -d "$ts" +%s 2>/dev/null) ))
      if [ "$cache_age" -lt 600 ] 2>/dev/null && [ "$cache_age" -ge 0 ] 2>/dev/null; then
        dr_data=$(jq -c '.data // empty' "$dr_cache_file" 2>/dev/null)
        dr_fresh=1
      fi
    fi
  fi
  if [ "$dr_fresh" != "1" ]; then
    dr_json=$(devradar --format json "$cwd" 2>/dev/null)
    if [ -n "$dr_json" ]; then
      dr_data=$(echo "$dr_json" | jq -c '.' 2>/dev/null)
    fi
    # Stamp the cache even when the scan yielded nothing, so a failing or slow
    # devradar is rate-limited too rather than retried every render.
    jq -n --argjson d "${dr_data:-null}" --arg t "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{timestamp:$t, data:$d}' > "$dr_cache_file" 2>/dev/null
  fi
  if [ -n "$dr_data" ] && [ "$dr_data" != "null" ]; then
    code_lines=$(echo "$dr_data" | jq -r '.summary.codeLines // 0' 2>/dev/null)
    if [ "$code_lines" -gt 0 ] 2>/dev/null; then
      fw_list=$(echo "$dr_data" | jq -r '.technologies.frameworks // [] | join("·")' 2>/dev/null)
      # No framework detected -> fall back to the dominant language
      [ -z "$fw_list" ] && fw_list=$(echo "$dr_data" | jq -r '.byLanguage[0].language // empty' 2>/dev/null)
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

# Widget: total output tokens across ALL sessions today (cached 5 min).
# (Transcripts no longer carry per-message cost, so tokens are the honest sum.)
if [ "$COMPACT" != "1" ] && [ -d "$HOME/.claude/projects" ]; then
  ct_cf="/tmp/claudefy-tokens-today.txt"
  ct_age=$(file_age "$ct_cf")
  if [ -z "$ct_age" ] || [ "$ct_age" -ge 300 ] 2>/dev/null; then
    find "$HOME/.claude/projects" -name '*.jsonl' -newermt "$(date +%Y-%m-%d) 00:00:00" -print0 2>/dev/null \
      | xargs -0 grep -h -o '"output_tokens":[0-9]*' 2>/dev/null \
      | awk -F: '{s += $2} END {print s + 0}' > "$ct_cf"
  fi
  ct_sum=$(cat "$ct_cf" 2>/dev/null)
  if [ "$ct_sum" -gt 0 ] 2>/dev/null; then
    add_l4 94 15 " $ICON_SIGMA $(human_tokens "$ct_sum") out today "
  fi
fi

# Widget: usage streak — consecutive days with Claude Code activity (cached 1h)
if [ "$COMPACT" != "1" ] && [ -d "$HOME/.claude/projects" ]; then
  st_cf="/tmp/claudefy-streak.txt"
  st_age=$(file_age "$st_cf")
  if [ -z "$st_age" ] || [ "$st_age" -ge 3600 ] 2>/dev/null; then
    st_dates=$(find "$HOME/.claude/projects" -name '*.jsonl' -mtime -40 \
      -printf '%TY-%Tm-%Td\n' 2>/dev/null | sort -u)
    streak=0; sd_i=0
    while [ "$sd_i" -lt 40 ]; do
      d=$(date -d "-${sd_i} day" +%Y-%m-%d 2>/dev/null)
      [ -z "$d" ] && break
      if echo "$st_dates" | grep -q "^$d$"; then
        streak=$((streak + 1)); sd_i=$((sd_i + 1))
      else
        # today may have no finished write yet — skip day 0 once
        if [ "$sd_i" -eq 0 ]; then sd_i=1; continue; fi
        break
      fi
    done
    echo "$streak" > "$st_cf"
  fi
  streak=$(cat "$st_cf" 2>/dev/null)
  [ "$streak" -ge 2 ] 2>/dev/null && add_l4 58 15 " $NF_TROPHY ${streak}d streak "
fi

for si in "${!SYS_BG[@]}"; do add_l4 "${SYS_BG[si]}" "${SYS_FG[si]}" "${SYS_TEXT[si]}"; done

add_l4 237 75 " Claudefy v$CLAUDEFY_VER "
add_l4 237 208 " Author: HoangAnhDev "

# ===========================================================================
# Output
# ===========================================================================
line1=$(render_line L1_BG L1_FG L1_TEXT)
line2=$(render_line L2_BG L2_FG L2_TEXT)
line4=$(render_line L4_BG L4_FG L4_TEXT)
if [ "$COMPACT" = "1" ]; then
  if [ "${#SYS_BG[@]}" -gt 0 ]; then
    line_sys=$(render_line SYS_BG SYS_FG SYS_TEXT)
    out_final=$(printf '%s\n%s\n%s' "$line1" "$line2" "$line_sys")
  else
    out_final=$(printf '%s\n%s' "$line1" "$line2")
  fi
elif [ "${#L3_BG[@]}" -gt 0 ]; then
  line3=$(render_line L3_BG L3_FG L3_TEXT)
  out_final=$(printf '%s\n%s\n%s\n%s' "$line1" "$line2" "$line3" "$line4")
else
  out_final=$(printf '%s\n%s\n%s' "$line1" "$line2" "$line4")
fi
printf '%s' "$out_final"
{ printf '%s\n' "$rc_key"; printf '%s' "$out_final"; } > "$rc_file" 2>/dev/null
