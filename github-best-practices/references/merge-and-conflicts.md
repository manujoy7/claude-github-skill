# Merging and Conflict Resolution

## Pre-merge gate

All of these before merging — no exceptions without explicit user override:

```bash
gh pr view <num> --json reviewDecision,mergeable,mergeStateStatus,statusCheckRollup
```

1. **Required approvals present** (`reviewDecision: APPROVED`).
2. **All review threads resolved** — verify via the GraphQL `reviewThreads` query (pr-review.md §5), not memory. If bot reviewers re-review per push, their review of the *current head SHA* must exist first.
3. **Required checks green on the current head** — `gh pr checks <num> --watch --fail-fast`. Gate on the exit code, not parsed output. Beware the stale-SHA trap: immediately after a push, a check-count of "0 pending" can mean "runs not registered yet", not "all passed". Confirm the checks belong to the head SHA you're about to merge.
4. **Branch up to date with base** if the repo requires it (`mergeStateStatus: BLOCKED` vs `BEHIND` tells you which gate is failing).
5. **User confirmed the merge** — merging is irreversible-ish and public.

## Choosing the merge strategy

**First constraint: what the repo allows** (`gh repo view --json squashMergeAllowed,mergeCommitAllowed,rebaseMergeAllowed`) **and what its history shows** (`git log --merges --oneline -10`). Match the house style. When genuinely free to choose:

| Strategy | History result | Choose when | Costs |
|---|---|---|---|
| **Squash** (`--squash`) | One commit per PR | PR's intra-history is messy fixups; repo reads history at PR granularity; enterprise default for app repos | Loses atomic commits, individual signatures, per-commit bisection |
| **Merge commit** (`--merge`) | All commits + merge node | Commits are individually meaningful and atomic; audit needs the true history | Non-linear graph; noisy if commits were sloppy |
| **Rebase** (`--rebase`) | Commits replayed linearly, no merge node | Linear-history mandate + meaningful commits | Rewrites SHAs → **breaks GPG/SSH commit signatures**; no merge point to revert as a unit |

Notes:

- **Squashing? The PR title/body become the commit message** — make the title conventional-commit-clean before merging; edit the message at merge time if needed.
- **Signed-commits-required + linear-history-required** is the one combo where GitHub's rebase button fails you (it re-signs as GitHub or drops signatures depending on setup). Solution: rebase locally, push, then fast-forward merge locally: `git checkout <default> && git merge --ff-only <branch> && git push` — allowed only if you have push rights that bypass the PR requirement for the ff push, otherwise use the merge queue / squash.
- Prefer `gh pr merge --auto <num> --<strategy> --delete-branch`: merges the moment gates pass, and cleans up. In repos with a **merge queue**, `--auto` enqueues; never bypass the queue with a manual merge.

## Resolving conflicts

Resolve locally, not in the web editor, for anything beyond trivial one-liners — locally you can run the tests before pushing.

```bash
git fetch origin
git rebase origin/<default>            # on your own PR branch
# conflict appears:
git status                              # which files
git diff                                # conflict markers in context
# understand BOTH sides before editing:
git log --oneline origin/<default> -5 -- <file>   # what changed upstream and why
# edit; a correct resolution often combines both intents, not "pick mine"
git add <file>
git rebase --continue
# run the test suite BEFORE pushing — a clean-merging resolution can still be wrong
git push --force-with-lease
```

Principles:

- **A conflict is two intents colliding.** Read the upstream commits that caused it; the right resolution frequently needs pieces of both sides. Blind "ours"/"theirs" is how regressions merge cleanly.
- **Semantic conflicts don't show markers.** Upstream renamed a function your branch calls: merges clean, breaks at runtime. This is why the full test run after resolution is non-negotiable.
- Repeated conflicts on the same file across a long-lived branch → enable `git config rerere.enabled true` (reuses your recorded resolutions), and consider whether the branch should be split/merged sooner.
- If mid-rebase things look wrong: `git rebase --abort` returns you to the pre-rebase state losslessly. Never push a resolution you don't understand.
- Multi-person branch (rare, discouraged): use `git merge origin/<default>` instead of rebase — never rewrite pushed history others are working on.

## Post-merge

```bash
git checkout <default> && git pull --ff-only
git branch -d <branch>                          # local
gh pr view <num> --json state                   # confirm MERGED
```

- Confirm the linked issue auto-closed; close it manually with a comment if the keyword was missing.
- If deployment follows merge, watch the deploy pipeline — merging isn't done until the default branch is green post-merge.
- **If the merge broke the default branch: revert first, investigate second.** `git revert <sha>` (for a squash/rebase merge) or `git revert -m 1 <merge-sha>` (for a merge commit) via a fast-tracked PR — or the "Revert" button on the merged PR's page — unblocks the whole team; the fix can then take its time in a new PR. Reverting is not an accusation — it's hygiene.

## Hotfixes

Even urgent fixes go through a PR (SKILL.md rule 1) — with an expedited path, not a bypassed one: minimal diff, `hotfix/` branch, one fast reviewer, CI must still run. If the org has a break-glass bypass policy, that's the user's call to invoke explicitly, and it gets documented in the PR. After a hotfix to a release branch, forward-port it to the default branch immediately (cherry-pick) so it isn't silently reintroduced next release.
