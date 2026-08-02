# claude-github-skill

An [Agent Skill](https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview) that teaches Claude enterprise-grade GitHub collaboration: commits, branching, pull requests, code review, merging, and repository governance for distributed, multi-contributor teams.

## What it does

When you work on git/GitHub tasks, Claude automatically loads this skill and follows enterprise standards instead of ad-hoc habits:

- **Detects your repo's conventions first** (CONTRIBUTING.md, PR template, allowed merge methods, commit history style) and follows them over its own defaults
- **Commits & branches** — Conventional Commits, atomic commits, branch naming, strategy selection (GitHub Flow / trunk-based / Git Flow)
- **PR authoring** — right-sized PRs (<400 lines), structured What/Why/How/Testing descriptions, draft-until-green, stacked PRs, issue linking
- **Code review** — prioritized reviewer checklist (correctness → security → tests → design), Conventional Comments severity prefixes, batched pending reviews, and **asks your approval before posting anything public**
- **Review responses** — every resolved thread cites the fixing commit SHA; verifies AI-reviewer claims before applying or dismissing them
- **Merging** — full pre-merge gate (approvals, resolved threads, green checks on the current head), strategy selection, local conflict resolution, revert-first recovery
- **Governance & security** — branch protection/rulesets, CODEOWNERS, merge queues, SHA-pinned Actions, least-privilege tokens, secret-scanning discipline

## Structure

```
github-best-practices/
├── SKILL.md                        # Entry point: rules, repo-detection, task routing
├── references/                     # Loaded on demand (progressive disclosure)
│   ├── commits-and-branching.md
│   ├── pr-authoring.md
│   ├── pr-review.md
│   ├── merge-and-conflicts.md
│   ├── repo-governance.md
│   └── ci-cd-and-security.md
└── evals/evals.json                # Test prompts
dist/github-best-practices.skill    # Packaged skill for one-click install
```

## Requirements

- `git` and the [GitHub CLI](https://cli.github.com/) (`gh`), authenticated via `gh auth login`

## Install

**Claude Desktop / Claude.ai (Pro/Max/Team):**
Settings → **Capabilities** → **Skills** → **Upload skill**, and select `dist/github-best-practices.skill`. (Or attach the `.skill` file in a chat and click **Save skill**.)

**Claude Code:**

```bash
git clone https://github.com/manujoy7/claude-github-skill.git
mkdir -p ~/.claude/skills
cp -r claude-github-skill/github-best-practices ~/.claude/skills/
```

Project-scoped alternative: copy into `.claude/skills/` inside a repo to share it with your team via version control.

## Use

No special invocation needed — the skill triggers automatically on GitHub work. Try:

- *"Open a pull request for these changes"*
- *"Review PR #42 and leave feedback"*
- *"The reviewer left comments on my PR — address them and resolve the threads"*
- *"Set up this repo for a 20-engineer team"*

Claude will always show you the exact content of any review, comment, or merge before posting it.

## License

[MIT](LICENSE)
