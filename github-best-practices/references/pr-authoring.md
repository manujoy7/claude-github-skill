# Pull Request Authoring

A PR is a request for a colleague's scarce attention. Everything here optimizes for reviewability: a reviewable PR gets reviewed fast and well; an unreviewable one gets rubber-stamped or ignored — both are failure modes.

## Size: the single biggest lever

- **Target under ~400 changed lines of substantive code**; review defect-detection falls off sharply beyond that. Under 200 is ideal.
- Generated files, lockfiles, snapshots, and pure renames don't count against the budget — but call them out in the description so reviewers know to skim them.
- **If a change is too big, split it before opening**, not after a reviewer complains:
  - Refactor-then-change: PR 1 is the pure no-behavior-change refactor, PR 2 the behavior change.
  - Layer by layer: schema/migration PR, then service PR, then UI PR.
  - Feature-flagged slices: merge incomplete-but-safe pieces dark.
- One PR = one concern. "Also fixed some unrelated lint while I was there" belongs in its own PR — it pollutes the diff and blocks the revert path.

## Stacked PRs (dependent chains)

When slices depend on each other, stack them: branch B off branch A, open PR-B **with base = branch A**, not the default branch — otherwise PR-B's diff shows all of A's changes too.

```bash
gh pr create --base feat/PROJ-1-schema --head feat/PROJ-2-service ...
```

- State the stack in each description: "Stacked on #101 — review only the last N commits here."
- After the base PR merges, retarget: `gh pr edit <num> --base <default>` and rebase the branch.
- Merge bottom-up, one at a time, letting CI re-run between.

## The description

Check `.github/PULL_REQUEST_TEMPLATE.md` first and fill it faithfully — an ignored template signals carelessness to every reviewer. If none exists, use:

```markdown
## What
One–three sentences: the change, in plain language.

## Why
The problem or requirement. Link the issue: Closes #123.

## How
Only the non-obvious: key design decisions, alternatives rejected and why,
anything a reviewer would otherwise have to reverse-engineer from the diff.

## Testing
How this was verified — commands run and their results, new tests added,
manual steps a reviewer can reproduce. Paste output, don't just assert.

## Screenshots / recordings
For any UI change: before/after.

## Risk & rollout
Migrations? Feature flag? Backward compatibility? Revert plan if bad?

## Review notes
Suggested reading order for a large diff; areas you want extra scrutiny on;
files safe to skim (generated, renames).
```

Rules:

- **Title follows the commit convention** (`feat(scope): …`) — in squash-merge repos the title *becomes* the commit subject.
- **Never write "see commits" or leave the body empty.** The description is the review's entry point and the future archaeologist's record.
- **Issue linking uses closing keywords** (`Closes/Fixes/Resolves #N`) so the issue auto-closes on merge and project boards update. `Refs #N` for related-but-not-closing.
- Be honest about what's untested or uncertain. Flagging "I'm unsure about the locking in X" gets you a careful look exactly where it's needed.

## Draft PRs and readiness

Open as **draft** (`gh pr create --draft`) until all of the following hold, then `gh pr ready`:

1. **You self-reviewed the full diff** (`gh pr diff` or the Files tab) as if it were someone else's. You'll catch debug prints, leftover TODOs, accidental file inclusions — cheaper than a reviewer catching them.
2. **CI is green** (`gh pr checks --watch --fail-fast`). Requesting human review with red CI wastes the reviewer's time and your review round.
3. **The description is complete** per the template above.
4. No secrets, credentials, or large binaries slipped into the diff.

Draft PRs are also the right vehicle for early design feedback — say explicitly "draft: seeking direction on the approach in `foo.py`, ignore the rest".

## Requesting review

- Respect `CODEOWNERS` — required owners are auto-requested; add others only with a reason ("adding @sam for the migration").
- 1–2 reviewers is the norm; a crowd diffuses responsibility and nobody reviews.
- If review hasn't started within the team's SLA (commonly one business day), a single polite nudge in the team channel beats a re-request storm.

## While the PR is open

- **Push responses to feedback as new commits** (or `--fixup` commits) — never rewrite already-reviewed commits mid-review. Force-pushing over reviewed history destroys the reviewer's "changes since last review" view. Tidy with autosquash only at the end, and announce it ("rebased to clean up fixups, no content change — diff vs. previous head is empty").
- Keep the branch rebased on the default branch if it falls significantly behind, especially before merge.
- Update the description if scope evolved — it must describe the PR as it *is*, not as it started.
