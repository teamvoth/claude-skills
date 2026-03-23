---
name: pr-review
description: Use this skill when the user asks to "review a PR", "review this pull request", "check the PR", "evaluate the PR", or wants to review and potentially merge an open pull request. Also use when the user wants to verify a PR meets all requirements before merging. Can be invoked with a PR number (e.g. `/pr-review 42`) or without to review the most recent open PR on the current branch.
version: 2.0.0
---

# PR Review

Evaluate a pull request by spawning five focused specialist sub-agents in parallel, each reviewing one dimension deeply. Aggregate their verdicts against CI status to make the final merge or block decision.

## Step 1: Identify the PR

If a PR number was provided, use it. Otherwise, find the most recent open PR on the current feature branch:

```bash
gh pr list --state open --json number,title,headRefName,baseRefName
```

Fetch the full PR details:

```bash
gh pr view <number> --json number,title,body,headRefName,baseRefName,isDraft
```

Extract the linked issue number from the PR body (`Closes #N`). If no issue is linked, flag it — every PR in this workflow must link to an issue. Do not proceed.

If the PR is a draft, comment that it must be marked ready for review first. Do not proceed.

## Step 2: Collect All Context Into Named Variables

Fetch each piece of context below and hold it in memory under the given name. **Do not spawn any sub-agents until all variables are populated.**

- **`ISSUE_BODY`** — `gh issue view <N> --json title,body`
- **`PRD_CONTENT`** — Read `docs/PRD/<feature-name>.md` (find the feature name from the PRD Reference field in the issue body). If the file does not exist, set `PRD_CONTENT = "PRD not found — file docs/PRD/<feature-name>.md is missing."` and note the discrepancy.
- **`ADR_CONTENTS`** — Find the Architectural Decisions section in the issue body. For each referenced ADR, read `docs/ADR/<NNNN>-<slug>.md` and concatenate with a `--- ADR: <filename> ---` header. If no ADRs are referenced, set `ADR_CONTENTS = "No ADRs referenced in this issue."`
- **`PR_DIFF`** — `gh pr diff <number>`. Save the diff once and use the Read tool to examine sections. Do not pipe `gh pr diff` through shell commands (`grep`, `awk`, `sed`) repeatedly.

If the diff is large, pass it in full. Do not truncate — truncation causes missed findings.

## Step 3: Spawn Five Parallel Sub-Agent Reviewers

**In a single message, invoke the Agent tool five times in parallel — one call per reviewer.** Do not call them sequentially.

Each agent prompt must include three parts in order:
1. The shared output format preamble (below)
2. The agent's specific scope instruction (below)
3. The full context block (below)

---

### Shared Output Format Preamble

Include this text verbatim at the start of every agent's prompt:

```
You are a specialized code reviewer. You will receive a complete PR diff, the GitHub issue it implements, the PRD for this feature, and any ADRs that apply. Your job is to evaluate one specific dimension only — do not comment outside your scope.

Return your findings in EXACTLY this format:

## [AGENT NAME] Review

**Verdict**: PASS | FAIL | WARN
(PASS = no issues; FAIL = blocking issues that must be fixed before merge; WARN = non-blocking observations worth noting)

**Findings**:
[If PASS: one sentence confirming what you checked and that it passed.]
[If FAIL or WARN: numbered list. For each finding: (1) what the issue is, (2) where — file name and line number if applicable, (3) why it matters.]

**Blocking Issues**: N | **Warnings**: N

Do not summarize the PR beyond what is needed to explain your findings.
```

---

### Agent 1 — Security Reviewer

Scope instruction:
```
Evaluate this PR exclusively for security vulnerabilities. Check:
(1) OWASP Top 10: injection (SQL, command, template, path traversal), broken auth, XSS, IDOR, security misconfiguration, sensitive data exposure, use of components with known vulnerabilities
(2) Hardcoded secrets, credentials, API keys, tokens, or environment values committed in code or tests
(3) Authentication and authorization: are protected resources actually protected, are permission checks present where the code implies they should be
(4) Input validation: is user-supplied data validated before use

If the diff contains no user-facing input or external data handling, state that explicitly and return PASS.
```

---

### Agent 2 — Test Quality Analyst

Scope instruction:
```
Evaluate this PR exclusively for test quality. Check:
(1) Does the test suite cover every behavior listed in the acceptance criteria — trace each criterion to at least one test
(2) Are integration or functional tests present where the feature involves multiple components interacting
(3) Would the tests actually catch regressions — look for tests that assert implementation details rather than behavior, tests with no meaningful assertions, or tests that would pass even if the production code were deleted
(4) Do the test file structure, naming conventions, and assertion patterns match the existing codebase style visible in the diff

Any acceptance criterion with no corresponding test is a FAIL.
```

---

### Agent 3 — Task Compliance Reviewer

Scope instruction:
```
Evaluate this PR exclusively for compliance with the issue and PRD. Check:
(1) For each acceptance criterion in the issue, trace it to the specific code that implements it — "the PR says it does X" is not evidence, find the code
(2) Scope: does the diff contain any changes not required by the acceptance criteria, even if they look like improvements
(3) PRD alignment: does the implementation reflect the intent described in the PRD, or does anything contradict the PRD's goals or out-of-scope boundaries
(4) Definition of done: evaluate each checklist item in the issue's Definition of Done section against the diff

Any unmet acceptance criterion is a FAIL. Any out-of-scope change is a FAIL.
```

---

### Agent 4 — Architecture & Standards Reviewer

Scope instruction:
```
Evaluate this PR exclusively for architectural and code quality issues. Check:
(1) ADR compliance: for each ADR provided, verify the implementation follows the decision. Deviations are a FAIL even if the code works — ADRs capture deliberate choices whose reasoning must be preserved
(2) Existing patterns: does the code follow the conventions visible in the diff context (naming, file organization, error handling style, module structure)
(3) Code quality: dead code, unused imports, variables declared but never used, unreachable branches
(4) Naming consistency: are names clear, accurate, and consistent with the surrounding codebase

If no ADRs were provided, state this and skip that check.
```

---

### Agent 5 — Performance & Reliability Reviewer

Scope instruction:
```
Evaluate this PR exclusively for performance and reliability issues. Check:
(1) Efficiency: obvious algorithmic inefficiencies, N+1 query patterns, unnecessary repeated work, or data fetched but not used
(2) Error handling: are errors from external calls, I/O, and parsing caught and handled; are error messages useful; does the code fail safely or leave state inconsistent on failure
(3) Edge cases: what happens with empty collections, null/undefined values, zero, negative numbers, very large inputs, concurrent calls — are these handled or do they produce panics/crashes/incorrect results
(4) Resource management: are connections, file handles, or other resources released properly

Only flag items that could cause production failures or measurable performance degradation — do not flag micro-optimizations.
```

---

### Context Block (append to every agent prompt)

```
---
PR NUMBER: <number>
PR TITLE: <title>

ISSUE BODY:
<ISSUE_BODY>

PRD CONTENT:
<PRD_CONTENT>

ARCHITECTURAL DECISION RECORDS:
<ADR_CONTENTS>

DIFF:
<PR_DIFF>
---
```

Replace `<number>`, `<title>`, `<ISSUE_BODY>`, `<PRD_CONTENT>`, `<ADR_CONTENTS>`, and `<PR_DIFF>` with the full text collected in Step 2. Inline the content — do not reference it abstractly.

## Step 4: Check CI

```bash
gh pr checks <number>
```

All checks must pass. If checks are still running, use `gh run watch` to wait for completion rather than sleep-based polling. Do not merge while anything is pending or failing.

Distinguish a code failure from an infrastructure flake — note the difference explicitly if relevant.

## Step 5: Aggregate Results and Decide

Collect the five agent reports. Build a decision table:

| Reviewer | Verdict | Blocking | Warnings |
|---|---|---|---|
| Security | | | |
| Test Quality | | | |
| Task Compliance | | | |
| Architecture & Standards | | | |
| Performance & Reliability | | | |
| CI | | — | — |

**Merge if and only if**: all five agents returned PASS or WARN (zero FAILs) AND CI is passing.

**Request changes if**: any agent returned FAIL, OR CI is failing with a code failure (not an infra flake).

**Wait**: if CI is still pending, use `gh run watch` to wait for completion before deciding.

Warnings do not block merge — include them in the review comment as observations.

---

### Everything passes → merge

```bash
gh pr merge <number> --squash --delete-branch
gh issue close <issue-number>
```

Report:
```
PR #<N> merged and branch deleted.
Issue #<N> closed.
```

---

### Anything fails → request changes

```bash
gh pr comment <number> --body "$(cat <<'EOF'
## Review

[One sentence summary — e.g. "Needs changes: 2 blocking findings across security and test coverage."]

### Sub-Agent Results

| Reviewer | Verdict | Blocking | Warnings |
|---|---|---|---|
| Security | ✅ PASS / ❌ FAIL / ⚠️ WARN | N | N |
| Test Quality | | | |
| Task Compliance | | | |
| Architecture & Standards | | | |
| Performance & Reliability | | | |

**CI**: ✅ Passing / ❌ Failing / ⚠️ Flake

---

[For each agent that returned FAIL or WARN, include its full findings block verbatim:]

### ❌ [Agent Name]: [brief label for the failure]

[Agent findings with file:line references]

---

[For each agent that returned PASS:]

### ✅ [Agent Name]

[Agent's one-sentence confirmation]

---

Resolve all FAIL items above and the PR will be ready to merge.
EOF
)"
```

Do not merge a PR with any open issues. Do not approve without merging — either it's ready and gets merged, or it gets blocked with clear feedback.

## Failure Modes

- **No linked issue**: comment asking for an issue link, do not review further
- **PRD not found**: report the discrepancy between the feature name in the issue and what exists in `docs/PRD/`
- **Draft PR**: do not merge; comment that it needs to be marked ready for review first
- **Agent returns malformed output**: re-invoke that single agent with a correction prompt before proceeding; do not guess at its verdict
