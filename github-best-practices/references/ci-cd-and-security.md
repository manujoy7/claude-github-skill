# CI/CD and Security

## Watching CI (do not hand-roll poll loops)

```bash
gh pr checks <num> --watch --fail-fast     # all checks on a PR; non-zero exit on failure
gh run watch <run-id> --exit-status        # a single workflow run
gh run view <run-id> --log-failed          # jump straight to what failed
```

Gate on **exit codes**. Hand-rolled `gh pr checks | jq` loops re-derive undocumented state semantics and hit the classic race: polled immediately after a push, "0 pending" means "runs not yet registered", not "all green". If you must hand-roll, gate on a *named required check reaching a terminal state on the current head SHA* — never on a zero-pending count.

When CI fails: read the failing step's log (`--log-failed`), reproduce locally, fix, push once. Don't push speculative fixes to "see if CI likes it" — each push burns a full CI cycle and spams reviewers.

## GitHub Actions: workflow hygiene

A PR-validation workflow every repo should have (adapt the steps to the stack):

```yaml
name: ci
on:
  pull_request:
  merge_group:        # REQUIRED if the repo uses a merge queue, else queued PRs never pass
permissions:
  contents: read      # least privilege at workflow level; widen per-job only as needed
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true    # newest push wins; don't waste runners on stale SHAs
jobs:
  test:
    runs-on: ubuntu-latest
    timeout-minutes: 15       # always set; hung jobs otherwise block for 6h
    steps:
      - uses: actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8   # v5 — pin by SHA
      - run: make lint test
```

Rules:

- **Pin third-party actions to a full commit SHA**, not a tag — tags are mutable; a hijacked action tag is a supply-chain compromise of every repo using it (this is exactly how the 2025 `tj-actions/changed-files` attack propagated). Keep the human-readable version in a comment; let Dependabot/Renovate bump the SHAs.
- **`permissions:` explicitly, least-privilege** at workflow level (`contents: read` baseline). Never grant `write` scopes to workflows that run untrusted PR code.
- **`pull_request_target` and `workflow_run` are the injection foot-guns**: they run with secrets in the base-repo context. Never check out and execute PR head code inside them. Fork PRs use plain `pull_request` (secrets unavailable — by design).
- **Never interpolate untrusted input into `run:` scripts** (`${{ github.event.pull_request.title }}` etc. is attacker-controlled). Pass via `env:` and quote.
- Required checks (the ones branch protection names) must be jobs that always report — a path-filtered job that's skipped never reports and blocks the merge; use a thin "required" aggregate job that `needs:` the real ones.
- Cache dependencies (`actions/cache` / setup-* built-ins); target <10 min PR feedback. Slow CI silently kills small-PR culture.

## Secrets

- Store in GitHub **Environments** (with protection rules and required reviewers for prod) or repo/org secrets — never in code, workflow files, or logs. Add `::add-mask::` for derived values.
- Prefer **OIDC federation** over long-lived cloud keys (`aws-actions/configure-aws-credentials` with a role, `google-github-actions/auth` with workload identity). No stored key, nothing to rotate or leak.
- **Enable secret scanning + push protection** on the repo/org. If a push is blocked: the secret is real → rotate it, rewrite it out of history, then push. Never "allow" through the block to save time; the credential is already in your reflog and CI logs.
- A leaked secret is compromised the moment it's pushed anywhere, even a private repo, even if force-pushed away seconds later. Rotation is the only fix; history rewriting is cleanup, not remediation.

## Dependency and code scanning

Enterprise baseline — enable and make the PR checks required:

- **Dependabot / Renovate** for dependency updates (grouped, scheduled — a daily flood of singleton PRs trains people to ignore them).
- **Dependency review action** on PRs — blocks introducing known-vulnerable or license-incompatible packages at review time, before they're in the tree.
- **CodeQL (or equivalent SAST)** on PRs + default branch schedule. Findings on deliberate test inputs are dismissed at the alert, not "fixed" in the test (see pr-review.md §6).

## Signed commits and provenance

Where the org requires verified provenance (regulated environments, release branches):

```bash
# SSH signing (simplest — reuses your existing key)
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519.pub
git config --global commit.gpgsign true
# The key must ALSO be uploaded to GitHub as a *signing* key (distinct from auth key)
```

Verify after one pushed commit: `gh api repos/{owner}/{repo}/commits/<sha> --jq .commit.verification` → `"reason":"valid"` is the goal; `"unknown_key"` = key not registered as signing key; `"unsigned"` = signing not actually configured.

Interactions to know:

- **Rebase re-signs** commits as *you* (fine if you're the author) — but GitHub's web rebase/squash buttons sign as GitHub or drop signatures; with a signed-commits rule this is why local rebase + `--ff-only` merge exists (merge-and-conflicts.md).
- **DCO shops**: `git commit -s` adds `Signed-off-by:`; it is a legal attestation, distinct from cryptographic signing; some orgs require both.
- Squash merges create a new commit signed by GitHub's web-flow key — acceptable under most policies, but confirm before recommending squash in a signed-commits repo.

## Deployment gates

- Use **Environments** (`environment: production` on the deploy job) to attach required approvers, wait timers, and branch restrictions (only default branch / `release/*` may deploy to prod).
- Deploy jobs get their own minimal permissions and OIDC role — never the CI-wide token.
- Post-merge: the merge isn't done until the default-branch build and deploy are green (merge-and-conflicts.md, Post-merge).
