# Code Review

Two roles, one file: **conducting** a review (§1–4) and **responding** to one (§5–6). Both sides follow rule 4 of SKILL.md: nothing is posted to GitHub without showing the user the exact content and getting confirmation.

## 1. What to review for (in priority order)

Work down this list; don't let (7) crowd out (1)–(4):

1. **Correctness** — does it do what the description claims? Edge cases: empty/null inputs, boundaries, concurrency, error paths, timezone/encoding. Trace at least one non-happy path by hand.
2. **Security** — injection (SQL/shell/path), authn/authz on every new endpoint or query, secrets in code or logs, unsafe deserialization, SSRF in anything that fetches URLs, new dependencies (typosquatting, maintenance status, license).
3. **Tests** — do tests exist for the new behavior *and* the bug being fixed (a fix without a regression test will regress)? Do they assert outcomes, not implementation details? Would they fail if the change were reverted?
4. **Design** — right place in the architecture? Reasonable coupling and API shape? Will the next person extend this or fork it? Backward compatibility of public interfaces, schemas, wire formats.
5. **Operability** — logging (right level, no sensitive payloads), metrics, failure modes visible, migrations reversible, feature-flag hygiene.
6. **Maintainability** — naming, dead code, duplication, comment quality (comments explain *why*), docs updated where behavior changed.
7. **Style** — only what linters can't catch. Never hand-review formatting a formatter handles; instead suggest adding the formatter to CI.

**Scope discipline:** review the change, not the codebase. Pre-existing problems the PR merely touches → file an issue, don't block. But if the PR makes an existing problem *worse*, that's in scope.

**Verify claims, don't trust them.** "Tested locally" without evidence → ask for the output or run it yourself: check out the branch (`gh pr checkout <num>`), run the tests, poke the edge case you're suspicious of. A 10-minute local run beats three rounds of comment ping-pong.

## 2. Writing review comments

Use **Conventional Comments** prefixes so severity is machine- and human-parseable:

| Prefix | Meaning | Blocks merge? |
|---|---|---|
| `issue:` | Defect or must-fix problem | Yes |
| `issue(security):` | Security defect | Yes, always |
| `suggestion:` | Concrete improvement, author's call | No, unless marked `(blocking)` |
| `question:` | Genuine question; answer may resolve it | Until answered |
| `nit:` | Trivial polish | Never |
| `praise:` | Something genuinely good — be specific | — |
| `thought:` | Non-actionable idea for later | No |

Comment craft:

- **Critique the code, never the author.** "This function re-reads the file per call" not "you're re-reading the file".
- **Say why, and what instead.** A naked "this is wrong" forces a guessing game. Best: attach a GitHub suggestion block the author can apply in one click:

  ````markdown
  issue: `total` overflows int32 for carts over ~21k items.

  ```suggestion
  total: int64 = 0
  ```
  ````

- **Distinguish "must" from "prefer" explicitly.** Authors can't read minds about which of your 14 comments block approval.
- Questions you could answer yourself in 30 seconds of reading — answer them yourself first.
- If you have more than ~3 fundamental design objections, stop line-commenting and request a synchronous conversation; design debates don't converge in comment threads.

## 3. Posting the review: batch, always

Never post line comments one-by-one — each one fires a notification and reads as a drive-by. Create a **pending review**, attach all comments, submit once with a verdict.

Simple cases: `gh pr review <num> --comment|--approve|--request-changes --body "…"`.

With line comments, use the API (single round trip — comments and event in one call):

```bash
# Everything in one submitted review. For a pending review instead,
# omit "event" here and submit later via the /events endpoint.
gh api repos/{owner}/{repo}/pulls/<num>/reviews -X POST \
  --input - <<'EOF'
{
  "commit_id": "<head SHA from: gh pr view <num> --json headRefOid -q .headRefOid>",
  "event": "REQUEST_CHANGES",
  "body": "Overall: solid approach; two blocking issues on the retry path, rest are nits.",
  "comments": [
    {"path": "src/retry.py", "line": 42, "side": "RIGHT",
     "body": "issue: retries hammer immediately — add backoff.\n\n```suggestion\n        time.sleep(min(2 ** attempt, 30))\n```"},
    {"path": "src/retry.py", "line": 58, "side": "RIGHT",
     "body": "nit: `MAX_TRIES` reads clearer than `N`."}
  ]
}
EOF
```

The **summary body** always states: overall verdict rationale, which comments are blocking, and something that works well. A wall of criticism with no orientation is demoralizing and slower to act on.

**Confirmation gate:** show the user the full review — every comment, the event type, the summary — and get a yes before the submitting call. If they want changes, edit and re-show.

## 4. Choosing the verdict

- **APPROVE** — mergeable as-is; remaining comments are nits/suggestions the author may take or leave. Approving with unfixed *blocking* comments is a contradiction.
- **REQUEST_CHANGES** — at least one `issue:` must be fixed before merge. Reserve it for that; using it for preferences erodes its meaning and, under branch protection, hard-blocks the merge until you re-review.
- **COMMENT** — feedback without a verdict: partial reviews, questions-first passes, reviews where you're not an appropriate approver.
- Approving means you share responsibility for the change. If you skimmed, say what you actually reviewed ("approved the API surface; didn't review the SQL in depth").
- Review promptly — within one business day. A stale PR rots: conflicts accrue and the author's context evaporates.

## 5. Responding to reviews on your PR

- **Respond to every comment** — with a fix, a reasoned pushback, or an answer. Silently ignoring a comment reads as either disrespect or an oversight; the reviewer can't tell which.
- **Pushback is legitimate.** Reviews are a dialogue, not commands. Disagree with reasons and evidence ("kept the loop: the comprehension version allocates 2× per profile run, output below"). If two rounds don't converge, escalate to a synchronous chat or a third opinion — not round five.
- **The resolving reply cites the commit** (SKILL.md rule 5):

  ```bash
  SHA=$(git rev-parse --short HEAD)
  # reply on the thread, then resolve it
  # "Fixed in ${SHA} — validation now runs after clock-skew adjustment."
  ```

  Banned replies: "Done", "Fixed", "Addressed", "Good catch, updated" — none lets the reviewer verify anything.
- **Who resolves a thread is repo culture — detect it.** Many enterprises reserve resolution for the reviewer who opened the thread. If CONTRIBUTING.md is silent and existing PRs show reviewers resolving, reply-with-SHA and leave the thread open.
- Push fixes as new commits during review (see pr-authoring.md) so reviewers get a clean "changes since your last review" diff.

### Resolving threads programmatically

Thread resolution is GraphQL-only. Get thread IDs, then resolve:

```bash
gh api graphql -f query='query($owner:String!,$repo:String!,$pr:Int!){
  repository(owner:$owner,name:$repo){ pullRequest(number:$pr){
    reviewThreads(first:100){ nodes{ id isResolved path comments(first:1){nodes{body}} } } } } }' \
  -f owner=OWNER -f repo=REPO -F pr=NUM

gh api graphql -f query='mutation($id:ID!){
  resolveReviewThread(input:{threadId:$id}){ thread{ isResolved } } }' -f id=PRRT_xxx
```

Verify state from GitHub, not memory: re-query `reviewThreads` before declaring "all resolved". If a bot reviewer (Copilot, SonarCloud, Gemini) re-reviews on each push, wait for its review of the **current head SHA** before trusting an unresolved-count of zero — the pre-push count is stale.

## 6. Handling automated and AI reviewers

AI reviewers mix real findings with confident hallucinations. Before applying **or** dismissing any bot comment, verify its load-bearing factual claim against the actual library code, official docs, or a local probe — never against the bot's assertion alone. Applying blindly ships wrong code; dismissing blindly discards the finding that was real. Either way, reply with the evidence: "Verified against `requests` 2.32 source: `timeout` covers connect+read separately — applied in `abc1234`" or "…— declining, current code is correct."

**Static-analysis hits on deliberate test inputs** (a synthetic secret fixture, an SSRF test targeting `169.254.169.254`) are false positives against the test's intent. Don't contort the test to appease the scanner — dismiss the alert at its source (code-scanning alert dismissal / SonarCloud resolution), which also clears any blocking check the alert created.

Batch your responses to bot rounds: fix everything from a bot's review in one push, not one push per comment — each push may trigger a fresh bot round.
