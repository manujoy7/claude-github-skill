---
name: github-best-practices
description: "Enterprise GitHub collaboration standards for distributed teams. Use whenever the user works with git or GitHub in a shared repository: creating commits or branches, opening or describing pull requests, reviewing a PR or responding to review feedback, resolving review threads, merging (strategy choice, CI gates, conflicts, post-merge cleanup), setting up branch protection, CODEOWNERS, PR templates, merge queues, or GitHub Actions. Also use when the user mentions 'PR', 'pull request', 'code review', 'commit message', 'branch', 'merge conflict', 'CI checks', or asks how a team should collaborate on GitHub — even if they don't say 'best practices'."
compatibility: "Requires git and the gh CLI (authenticated). Works in Claude Code, Cowork, and any agent with shell access."
metadata:
  version: "1.0.0"
license: MIT
---

# GitHub Best Practices

Standards for contributing in a distributed, multi-contributor GitHub environment: commits, branches, pull requests, code review, merging, and repository governance to enterprise quality.

## Step 0 — Detect the repo's conventions before imposing any

Enterprise repos differ. A "best practice" that contradicts the team's documented convention is a defect. Before committing, opening a PR, or reviewing, spend one pass discovering local rules:

```bash
# Team conventions and templates
ls CONTRIBUTING.md .github/CONTRIBUTING.md .github/PULL_REQUEST_TEMPLATE.md \
   .github/ISSUE_TEMPLATE .github/CODEOWNERS docs/CONTRIBUTING.md 2>/dev/null

# Actual default branch — never assume "main"
gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'

# Merge strategy the repo allows (tells you squash vs merge vs rebase culture)
gh repo view --json squashMergeAllowed,mergeCommitAllowed,rebaseMergeAllowed

# Commit style in recent history (conventional? ticket prefixes? capitalization?)
git log --oneline -15

# Hook framework present?
ls lefthook.yml .pre-commit-config.yaml .husky commitlint.config.* 2>/dev/null
```

**Precedence: repo's documented conventions > observed history patterns > this skill's defaults.** When CONTRIBUTING.md conflicts with this skill, follow CONTRIBUTING.md and say so.

## Critical rules (non-negotiable)

1. **Never push directly to the default branch.** All changes go through a PR, even one-line fixes. This is what makes review, CI gating, and audit trails possible.
2. **Never force-push shared branches; on your own PR branch use `--force-with-lease` only.** Plain `--force` can silently destroy a teammate's pushed work; `--force-with-lease` aborts if the remote moved.
3. **Never claim "tested", "verified", or "CI is green" without command output showing it.** If you didn't run it, say so. Trust in a multi-contributor team is built on accurate status reports.
4. **Get explicit user confirmation before any public or irreversible action**: posting a review, commenting on a PR, merging, closing a PR, or deleting a remote branch. Show exactly what will be posted/merged first. Drafting locally needs no confirmation; publishing does.
5. **Never resolve a review thread with a bare "Done"/"Fixed".** Every resolving reply cites the commit SHA and one sentence of what changed. Reviewers must be able to verify without archaeology.
6. **Never merge with unresolved review threads or failing required checks** unless the user explicitly overrides — and then note the override in the PR.
7. **Never commit secrets, credentials, or tokens** — and never work around a blocked push by disabling secret scanning. Rotate anything that leaked.
8. **Commit before rebase; rebase before merge.** A dirty tree aborts rebases half-way; an un-rebased branch merges against stale context.
9. **No editorializing in commits, PRs, or review replies.** State what changed and why — not how good it is. Never add AI attribution/signatures unless the repo requires it.

## Task routing

Load the reference for the task at hand — don't load all of them:

| You are about to… | Read |
|---|---|
| Write commits, name a branch, pick a branching strategy | `references/commits-and-branching.md` |
| Open a PR, write its description, size or split a change, stack PRs | `references/pr-authoring.md` |
| Review someone's PR, or respond to review feedback on yours | `references/pr-review.md` |
| Merge a PR, choose merge strategy, resolve conflicts, clean up after | `references/merge-and-conflicts.md` |
| Set up branch protection, CODEOWNERS, templates, labels, merge queue | `references/repo-governance.md` |
| Work with GitHub Actions, CI gates, signed commits, security scanning | `references/ci-cd-and-security.md` |

## Standard contributor loop (quick reference)

```bash
# 1. Start clean from the real default branch
DEFAULT=$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name')
git checkout "$DEFAULT" && git pull --ff-only
git checkout -b feat/TICKET-123-short-description

# 2. Work in small, atomic commits
git add -p                                  # stage intentionally, hunk by hunk
git commit -m "feat(scope): add X"          # see commits-and-branching.md

# 3. Before opening the PR: self-review and sync
git fetch origin && git rebase "origin/$DEFAULT"
git diff "origin/$DEFAULT"...HEAD           # read your own diff first

# 4. Open the PR (draft until CI is green and it's ready for humans)
git push -u origin HEAD
gh pr create --draft --fill                 # then edit per pr-authoring.md

# 5. Watch CI — use native watchers, never hand-rolled poll loops
gh pr checks --watch --fail-fast

# 6. Mark ready, request review, respond per pr-review.md
gh pr ready

# 7. Merge per repo policy, then clean up
gh pr merge --auto                          # strategy: see merge-and-conflicts.md
git checkout "$DEFAULT" && git pull --ff-only && git branch -d feat/TICKET-123-short-description
```

## Cross-cutting habits for multi-contributor repos

- **Verify your branch after any detour.** Switching to another PR mid-task and forgetting to switch back is the classic way edits land on the wrong branch. `git branch --show-current` costs nothing — run it before resuming edits and before staging. If work landed wrong: `git stash push -u -m "misplaced" -- <paths>` (`-u` so new files come along), checkout the right branch, `git stash pop`.
- **Prefer `gh` (or the GitHub MCP) over raw REST calls or the web UI** for PRs, reviews, and checks: consistent auth, `--json` output, clearer errors. Drop to `gh api` only for endpoints porcelain doesn't cover.
- **One PR = one worktree when working several in parallel** (`git worktree add ../repo-pr42 branch-name`) — eliminates cross-PR contamination entirely.
- **Link work to issues** (`Closes #123` in the PR body) so project tracking updates automatically on merge.
- **When the user's request is ambiguous about a public action's wording** (review tone, PR title, merge strategy), show a draft and ask — don't guess and publish.

## Failure recovery snippets

```bash
git reset --soft HEAD~1        # undo last commit, keep changes staged
git commit --amend --no-edit   # add forgotten file to last (unpushed!) commit
git revert <sha>               # undo a pushed commit safely (new inverse commit)
git reflog                     # find "lost" commits after a bad reset/rebase
git rebase --abort             # bail out of a conflicted rebase cleanly
```

Never amend or rebase commits that are already on a shared branch others may have pulled — revert instead.
