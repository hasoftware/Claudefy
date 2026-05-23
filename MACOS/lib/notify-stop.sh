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

# Save session stats
STATS_FILE="$HOME/.claude/claudefy-stats.jsonl"
{
  _proj="$project"; [ -z "$_proj" ] && _proj='unknown'
  _sid=$(get '.session_id')
  _model=$(get '.model.id'); [ -z "$_model" ] && _model=$(echo "$input" | jq -r '.model // "unknown"' 2>/dev/null)
  _cost=$(get '.cost.total_cost_usd'); [ -z "$_cost" ] && _cost=0
  _dur=$(get '.cost.total_duration_ms'); [ -z "$_dur" ] && _dur=0
  _ladd=$(get '.cost.total_lines_added'); [ -z "$_ladd" ] && _ladd=0
  _lrm=$(get '.cost.total_lines_removed'); [ -z "$_lrm" ] && _lrm=0
  _tin=$(get '.context_window.total_input_tokens'); [ -z "$_tin" ] && _tin=0
  _tout=$(get '.context_window.total_output_tokens'); [ -z "$_tout" ] && _tout=0
  _tp=$(get '.transcript_path')
  _turns=0
  if [ -n "$_tp" ] && [ -f "$_tp" ]; then
    _turns=$(grep -c '"type":"user"' "$_tp" 2>/dev/null || echo 0)
  fi
  _ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)
  jq -nc \
    --arg ts "$_ts" \
    --arg sid "$_sid" \
    --arg proj "$_proj" \
    --arg model "$_model" \
    --argjson cost "${_cost:-0}" \
    --argjson dur "${_dur:-0}" \
    --argjson ladd "${_ladd:-0}" \
    --argjson lrm "${_lrm:-0}" \
    --argjson tin "${_tin:-0}" \
    --argjson tout "${_tout:-0}" \
    --argjson turns "${_turns:-0}" \
    '{ts:$ts,sid:$sid,project:$proj,model:$model,cost:$cost,dur_ms:$dur,lines_add:$ladd,lines_rm:$lrm,tok_in:$tin,tok_out:$tout,turns:$turns}' \
    >> "$STATS_FILE"
} 2>/dev/null

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

# Native macOS notification via osascript
if command -v osascript >/dev/null 2>&1; then
  esc_msg=$(printf '%s' "$msg" | sed 's/"/\\"/g')
  osascript -e "display notification \"$esc_msg\" with title \"Claudefy\"" >/dev/null 2>&1 &
fi

jq -nc --arg s "$seq" '{terminalSequence:$s}'
