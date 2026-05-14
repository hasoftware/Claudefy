#!/usr/bin/env bash
# Claudefy Stop hook - bell + toast notification + quota alerts.
#
# Author     : Hoang Anh Dev
# Admin      : HASOFTWARE
# Telegram   : https://t.me/hasoftware
# Repository : https://github.com/hasoftware/Claudefy

set +e
export LANG=en_US.UTF-8
input=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

# Thresholds (edit freely)
T_5H=80
T_7D=80
T_OPUS_7D=80
T_CONTEXT=10
T_COST_USD=5

# Extract fields
get() { echo "$input" | jq -r "$1 // empty" 2>/dev/null; }

cwd=$(get '.workspace.current_dir'); [ -z "$cwd" ] && cwd=$(get '.cwd')
project=$(basename "$cwd" 2>/dev/null); [ -z "$project" ] && project='Claude'

fh=$(get '.rate_limits.five_hour.used_percentage')
sd=$(get '.rate_limits.seven_day.used_percentage')
op=$(get '.rate_limits.seven_day_opus.used_percentage')
ctx=$(get '.context_window.remaining_percentage')
cost=$(get '.cost.total_cost_usd')

# Compare integer percentages
ge() { [ "${1%.*}" -ge "$2" ] 2>/dev/null; }
le() { [ "${1%.*}" -le "$2" ] 2>/dev/null; }

warnings=()
[ -n "$fh"  ] && ge "$fh"  "$T_5H"      && warnings+=("5h quota $(printf '%.0f' "$fh")%")
[ -n "$sd"  ] && ge "$sd"  "$T_7D"      && warnings+=("7d quota $(printf '%.0f' "$sd")%")
[ -n "$op"  ] && ge "$op"  "$T_OPUS_7D" && warnings+=("Opus 7d $(printf '%.0f' "$op")%")
[ -n "$ctx" ] && le "$ctx" "$T_CONTEXT" && warnings+=("Context only $(printf '%.0f' "$ctx")% left")
if [ -n "$cost" ]; then
  if awk -v c="$cost" -v t="$T_COST_USD" 'BEGIN{exit !(c+0 >= t+0)}'; then
    warnings+=("Cost \$$(printf '%.2f' "$cost")")
  fi
fi

if [ "${#warnings[@]}" -gt 0 ]; then
  IFS='; ' joined="${warnings[*]}"
  msg="[!] $project - $joined"
  beeps=3
else
  msg="$project - Claude is ready"
  beeps=1
fi

# Compose terminal sequence: OSC 9 (toast) + BEL repeated
ESC=$'\033'
BEL=$'\007'
seq="${ESC}]9;${msg}${BEL}"
i=0
while [ "$i" -lt "$beeps" ]; do
  seq="${seq}${BEL}"
  i=$((i + 1))
done

# Also fire libnotify if available, for desktop notification on Linux
if command -v notify-send >/dev/null 2>&1; then
  notify-send -t 5000 "Claudefy" "$msg" >/dev/null 2>&1 &
fi

jq -nc --arg s "$seq" '{terminalSequence:$s}'
