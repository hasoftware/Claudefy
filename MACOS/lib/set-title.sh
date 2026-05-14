#!/usr/bin/env bash
# Claudefy SessionStart hook - set terminal window/tab title.
#
# Author     : Hoang Anh Dev
# Admin      : HASOFTWARE
# Telegram   : https://t.me/hasoftware
# Repository : https://github.com/hasoftware/Claudefy

set +e
export LANG=en_US.UTF-8
input=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

# Optional debug
# echo "$input" > /tmp/claude-sessionstart-input.json

get() { echo "$input" | jq -r "$1 // empty" 2>/dev/null; }
cwd=$(get '.cwd')
[ -z "$cwd" ] && cwd=$(get '.workspace.current_dir')
project=$(basename "$cwd" 2>/dev/null)
[ -z "$project" ] && project='Claude'

title="$project - Claude Code"

ESC=$'\033'
BEL=$'\007'
seq="${ESC}]2;${title}${BEL}"

jq -nc --arg s "$seq" '{terminalSequence:$s}'
