# Commits and Branching

## Conventional Commits

Format (per conventionalcommits.org):

```
<type>[optional scope][!]: <description>

[optional body]

[optional footer(s)]
```

**Types and semantic-versioning impact:**

| Type | Use for | SemVer |
|---|---|---|
| `feat` | New user-facing capability | MINOR |
| `fix` | Bug fix | PATCH |
| `docs` | Documentation only | — |
| `style` | Formatting, no logic change | — |
| `refactor` | Restructure without behavior change | — |
| `perf` | Performance improvement | PATCH |
| `test` | Add/adjust tests | — |
| `build` | Build system, dependencies | — |
| `ci` | CI configuration | — |
| `chore` | Maintenance not touching src/tests | — |
| `revert` | Reverts a previous commit | matches reverted |

**Breaking changes** — `!` after type/scope, or a `BREAKING CHANGE:` footer (both is clearest):

```
feat(api)!: remove deprecated /v1/users endpoint

BREAKING CHANGE: clients must migrate to /v2/users; response shape
changed from array to paginated object.
```

**Description rules:** imperative mood ("add", not "added/adds"), no trailing period, ≤72 chars for the whole subject line, lowercase after the colon unless a proper noun.

**Body:** explain *why* and any non-obvious *how*. The diff shows what changed; the body records what the diff can't — the constraint, the rejected alternative, the bug's root cause. Wrap at 72 chars.

**Footers:** issue references (`Fixes #123`, `Refs PROJ-456`), `Co-authored-by:` for pairing, `Signed-off-by:` where DCO is required (`git commit -s`).

**Examples:**

```
fix(auth): reject expired refresh tokens on rotation

Rotation accepted tokens past exp because validation ran before the
clock-skew adjustment. Validate after adjustment, matching login flow.

Fixes #482
```

```
refactor(billing): extract invoice tax calculation into TaxEngine

No behavior change; prepares for per-region rules in PROJ-901.
```

## Atomic commits

One commit = one self-contained logical change that builds and passes tests on its own.

Why it matters in a team: `git bisect` can find the breaking commit, `git revert` can undo one change without collateral, and reviewers can read history as a narrative.

- Mixed changes get split: `git add -p` to stage per hunk.
- Follow-up fixes to your own unpushed/PR commits: `git commit --fixup <sha>` then `git rebase -i --autosquash` before requesting review — no "oops", "WIP", "address comments" commits in final history unless the repo squash-merges anyway (check with `gh repo view --json squashMergeAllowed,mergeCommitAllowed,rebaseMergeAllowed`; if squash is the only allowed method, intra-PR tidiness matters less but the PR title/description becomes the commit — write it accordingly).
- Never mix a refactor with a behavior change in one commit; reviewers can't tell which lines are "safe".

## Branch naming

Default pattern (defer to repo convention if history shows another):

```
<type>/<ticket>-<kebab-description>
feat/PROJ-123-oauth-device-flow
fix/PROJ-456-null-invoice-total
chore/upgrade-node-22
hotfix/1.4.1-cve-2026-1234
release/2.3.0
```

Rules: lowercase, hyphens not underscores, no personal names as the whole name (`alice/fix` tells teammates nothing), short enough to type. Include the ticket ID when one exists — many orgs auto-link branches to issues by it.

Delete branches after merge (`gh pr merge --delete-branch` or repo auto-delete setting). Stale branches are where confusion and accidental re-pushes live.

## Choosing a branching strategy

Recommend based on the team's shape — don't default to Git Flow:

| Strategy | Fits | Shape |
|---|---|---|
| **GitHub Flow** (default recommendation) | Continuously deployed services, most teams | Short-lived feature branches off default → PR → merge → deploy |
| **Trunk-based** | High-maturity CI, feature flags in place | Branches live hours–2 days max; incomplete work ships dark behind flags |
| **Git Flow** | Versioned/boxed releases, multiple supported versions | `develop` + `feature/*` + `release/*` + `hotfix/*`; heavyweight — only when release branches are genuinely needed |
| **Release branches only** | Libraries/SDKs supporting N.x and N-1.x | GitHub Flow + long-lived `release/N.x` maintenance branches; fixes land on default first, then cherry-pick back |

Whatever the strategy: keep branches short-lived. A branch older than ~2 weeks accrues merge-conflict debt daily; prefer merging incomplete-but-safe work behind a flag over letting a branch age.

## Keeping a branch current

```bash
git fetch origin
git rebase origin/<default>     # preferred on your own PR branch: linear, reviewable
# or, if the branch is shared with another human:
git merge origin/<default>      # never rebase what others have pulled
```

Rebase rewrites SHAs — after a rebase, push with `--force-with-lease` (never plain `--force`). If GitHub reports the PR has conflicts, rebase locally and resolve there rather than using the web conflict editor for anything non-trivial: local resolution lets you run tests before pushing.
