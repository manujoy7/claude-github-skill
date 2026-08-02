# Repository Governance

Setting up a repo so best practices are enforced by the platform, not by vigilance. Changing these settings is a repo-admin action — always show the user the exact configuration and confirm before applying.

## Branch protection / rulesets

Prefer **rulesets** (newer, layerable, can apply org-wide and to tag patterns) over classic branch protection where available. Enterprise baseline for the default branch:

- **Require a pull request before merging** — ≥1 approval (2 for high-stakes repos); **dismiss stale approvals on new commits**; **require review from Code Owners** if CODEOWNERS exists.
- **Require status checks to pass** — name the specific required checks (build, test, lint, security scan) and **require branches to be up to date** for repos where semantic conflicts bite (see merge-and-conflicts.md).
- **Require conversation resolution before merging** — platform-enforces SKILL.md rule 6.
- **Block force pushes and deletions** on protected branches.
- **Require signed commits** where provenance matters (see ci-cd-and-security.md).
- **Restrict who can push** — even admins go through PRs; enable "Do not allow bypassing the above settings" unless a documented break-glass process exists.
- Apply a matching ruleset to `release/*` branches and protect tags matching `v*` from deletion/moving.

```bash
# Inspect current protections
gh api repos/{owner}/{repo}/rulesets
gh api repos/{owner}/{repo}/branches/<default>/protection   # classic
```

## Merge queue

For busy repos (roughly >10 merges/day or frequent "green PR breaks main" incidents): enable the merge queue on the default branch. It re-tests each PR against the actual future state of the branch before merging, eliminating the stale-CI race entirely. Contributors then use `gh pr merge --auto` to enqueue; manual merges bypass the queue and must not be used.

## CODEOWNERS

`.github/CODEOWNERS` maps paths to required reviewers — last matching pattern wins:

```
# Default owners for everything not matched below
*                   @org/backend-team

# Order matters: later matches override earlier ones
/docs/              @org/docs-team
*.tf                @org/platform-team
/src/auth/          @org/security-team @alice
/.github/workflows/ @org/platform-team          # protect CI from drive-by edits
```

Guidance:

- Owners must be teams or users **with write access**, else the entry silently does nothing. Validate in the GitHub UI (CODEOWNERS errors view) after editing.
- Own the sensitive surfaces at minimum: auth, payments, infra-as-code, CI workflows, public API definitions, CODEOWNERS itself.
- Prefer teams over individuals — individuals go on vacation and reviews stall.
- Combine with "require review from Code Owners" in protection rules, or it's advisory only.

## Templates

- **`.github/PULL_REQUEST_TEMPLATE.md`** — encode the description structure from pr-authoring.md. Keep it short; ten-section templates get deleted, not filled. Multiple templates can live in `.github/PULL_REQUEST_TEMPLATE/` (selected via `?template=` URL param).
- **Issue forms** (`.github/ISSUE_TEMPLATE/*.yml`) — structured YAML forms beat freeform markdown for bug reports (required repro steps, version dropdowns). Add `config.yml` with `blank_issues_enabled: false` and contact links for questions → discussions/support.
- **`CONTRIBUTING.md`** — the authoritative source this skill's Step-0 detection looks for. Document: branch naming, commit convention, merge strategy, review SLAs, who resolves review threads, test requirements. If the team has a convention that exists only in someone's head, put it here.
- `CODE_OF_CONDUCT.md`, `SECURITY.md` (vulnerability reporting channel), `SUPPORT.md` round out the community health set; org-level `.github` repo can provide defaults for all repos.

## Labels, milestones, auto-management

- Standardize a small label taxonomy: type (`bug`, `feature`, `docs`), priority (`P0`–`P2`), status (`needs-triage`, `blocked`), plus `good-first-issue` for onboarding. Sync across repos with `gh label clone` or a labels-as-code action.
- Auto-label PRs by touched paths with the `labeler` action — powers routing and release notes.
- Stale-branch and stale-PR hygiene: repo setting "Automatically delete head branches" ON; a scheduled stale-PR action that pings (not closes) after the review SLA lapses.
- Release automation (Release Please / semantic-release) pairs with conventional commits to generate changelogs and version bumps — worth recommending when the user asks about releases, but keep the setup in its own PR.

## Repo settings quick audit

```bash
gh repo view --json squashMergeAllowed,mergeCommitAllowed,rebaseMergeAllowed,\
deleteBranchOnMerge,defaultBranchRef,visibility,isTemplate
```

Recommended defaults for a multi-contributor service repo: allow exactly **one** merge method (consistency beats flexibility), `deleteBranchOnMerge: true`, squash-merge title default = "Pull request title" so conventional-commit titles carry through.
