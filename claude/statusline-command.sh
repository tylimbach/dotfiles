#!/usr/bin/env bash
# Claude Code statusLine command
# Mirrors ~/.zshrc _prompt_precmd: time user@host cwd (git-branch), then
# gauges: the context window used, and the 5-hour and 7-day rate limits.
# Needs jq (Windows: winget install jqlang.jq).

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // empty')
[ -z "$cwd" ] && cwd="$(pwd)"

# Git branch (no-optional-locks avoids interfering with running git operations)
branch=""
if git -C "$cwd" --no-optional-locks rev-parse --git-dir &>/dev/null 2>&1; then
    branch=$(git -C "$cwd" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)
fi

# ANSI colors (match zshrc: green time, cyan user, blue host, yellow path)
GREEN='\033[32m'
CYAN='\033[36m'
BLUE='\033[34m'
YELLOW='\033[33m'
RED='\033[31m'
DIM='\033[2m'
RESET='\033[0m'

# Rate-limit usage (Claude.ai Pro/Max only, present after first API response).
# Color each gauge by severity: dim <50%, yellow 50-79%, red >=80%.
usage_color() {
    local pct=${1%.*}   # strip decimals
    if   [ "$pct" -ge 80 ]; then printf '%b' "$RED"
    elif [ "$pct" -ge 50 ]; then printf '%b' "$YELLOW"
    else printf '%b' "$DIM"
    fi
}

# Context window used, once the session has a response.
ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
ctx_str=""
if [ -n "$ctx_pct" ]; then
    ctx_str="  ${DIM}ctx${RESET} $(usage_color "$ctx_pct")$(printf '%.0f' "$ctx_pct")%${RESET}"
fi

rate_str=""
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
if [ -n "$five_pct" ]; then
    rate_str="${rate_str}  ${DIM}5h${RESET} $(usage_color "$five_pct")$(printf '%.0f' "$five_pct")%${RESET}"
fi
if [ -n "$week_pct" ]; then
    rate_str="${rate_str}  ${DIM}7d${RESET} $(usage_color "$week_pct")$(printf '%.0f' "$week_pct")%${RESET}"
fi

time_str=$(date +%H:%M:%S)
user_str=$(whoami)
host_str=$(hostname -s 2>/dev/null || hostname)

# Shorten $HOME to ~
short_cwd="${cwd/#$HOME/~}"

line="${GREEN}${time_str}${RESET} ${CYAN}${user_str}${RESET}@${BLUE}${host_str}${RESET} ${YELLOW}${short_cwd}${RESET}"
[ -n "$branch" ] && line="${line} (${branch})"
line="${line}${ctx_str}${rate_str}"

printf "%b\n" "$line"
