#!/bin/bash

# Read input from stdin
input=$(cat)

# Extract model information
model=$(echo "$input" | jq -r '.model.display_name')

# Extract current directory name
current_dir=$(echo "$input" | jq -r '.workspace.current_dir' | xargs basename)

# Get git branch (or 'no-git' if not a git repository)
branch=$(git -C "$(echo "$input" | jq -r '.workspace.current_dir')" branch --show-current 2>/dev/null || echo 'no-git')

# Get session tokens
tokens=$(~/.claude/get-session-tokens.sh <<< "$input")

# Get cost information
cost=$(~/.claude/get-cost.sh)

# Format and output the status line with proper colors and formatting
# New format: <model> xx% left 78/908
printf "\033[0;38;2;91;155;214m%s\033[0m " "$model"
printf "\033[0;38;5;248m%s\033[0m " "$tokens"
printf "\033[0;38;5;178m%s\033[0m\n" "$cost"