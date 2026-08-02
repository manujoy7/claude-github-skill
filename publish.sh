#!/usr/bin/env bash
# One-time publish script for manujoy7/claude-github-skill
# Prereq: gh auth login   (authenticate in your browser first)
set -euo pipefail

command -v gh >/dev/null || { echo "Install GitHub CLI first: https://cli.github.com"; exit 1; }
gh auth status >/dev/null || { echo "Run 'gh auth login' first."; exit 1; }

cd "$(dirname "$0")"
if [ ! -d .git ]; then
  git init -b main
  git add .
  git commit -m "feat: add github-best-practices agent skill for Claude"
fi

# Creates the public repo under your account and pushes in one step
gh repo create manujoy7/claude-github-skill \
  --public \
  --description "Agent Skill: enterprise GitHub best practices for Claude (commits, PRs, code review, merging, governance)" \
  --source . --push

echo "Done: https://github.com/manujoy7/claude-github-skill"
