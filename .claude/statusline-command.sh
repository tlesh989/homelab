#!/usr/bin/env bash
input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
vim_mode=$(echo "$input" | jq -r '.vim.mode // empty')
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_resets=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')

# Shorten home directory
cwd="${cwd/#$HOME/\~}"

# Git branch (skip optional locks)
git_branch=$(GIT_OPTIONAL_LOCKS=0 git -C "${cwd/#\~/$HOME}" rev-parse --abbrev-ref HEAD 2>/dev/null)

parts=""

# cwd
parts=$(printf "\033[34m%s\033[0m" "$cwd")

# git branch
if [ -n "$git_branch" ]; then
  parts="$parts  \033[33m$git_branch\033[0m"
fi

# model
if [ -n "$model" ]; then
  parts="$parts  \033[36m$model\033[0m"
fi

# context usage
if [ -n "$used" ]; then
  used_int=$(printf '%.0f' "$used")
  if [ "$used_int" -ge 80 ]; then
    ctx_color="\033[31m"
  elif [ "$used_int" -ge 50 ]; then
    ctx_color="\033[33m"
  else
    ctx_color="\033[32m"
  fi
  parts="$parts  ${ctx_color}ctx:${used_int}%\033[0m"
fi

# 5-hour session usage + time until reset
if [ -n "$five_pct" ]; then
  five_int=$(printf '%.0f' "$five_pct")
  if [ "$five_int" -ge 80 ]; then
    five_color="\033[31m"
  elif [ "$five_int" -ge 50 ]; then
    five_color="\033[33m"
  else
    five_color="\033[32m"
  fi
  session_str="${five_color}5h:${five_int}%\033[0m"
  if [ -n "$five_resets" ]; then
    now=$(date +%s)
    secs_left=$(( five_resets - now ))
    if [ "$secs_left" -gt 0 ]; then
      mins_left=$(( secs_left / 60 ))
      if [ "$mins_left" -ge 60 ]; then
        hrs=$(( mins_left / 60 ))
        mins=$(( mins_left % 60 ))
        reset_str=$(printf "%dh%02dm" "$hrs" "$mins")
      else
        reset_str="${mins_left}m"
      fi
      session_str="$session_str \033[90m(resets ${reset_str})\033[0m"
    fi
  fi
  parts="$parts  $session_str"
fi

# vim mode
if [ -n "$vim_mode" ]; then
  parts="$parts  \033[35m[$vim_mode]\033[0m"
fi

printf "%b" "$parts"
