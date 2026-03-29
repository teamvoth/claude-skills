---
name: pr-review
description: Use this skill when the user asks to "review a PR", "review this pull request", "check the PR", "evaluate the PR", or wants to review and potentially merge an open pull request. Also use when the user wants to verify a PR meets all requirements before merging. Can be invoked with a PR number (e.g. `/pr-review 42`) or without to review the most recent open PR on the current branch.
version: 3.0.0
---

# PR Review

Evaluate a pull request by spawning six focused specialist sub-agents in parallel, each reviewing one dimension deeply. Aggregate their verdicts against CI status to make the final merge or block decision.

## Step 1: Collect PR Context

Run the context collection script. If a PR number was provided as an argument, pass it; otherwise let the script discover from the current branch.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/pr-review/collect-context.sh" [PR_NUMBER]
```

The script validates the PR (not draft, has linked issue), fetches the linked issue, and returns JSON:

```json
{
  "pr": { "number": 42, "title": "...", "headRef": "...", "baseRef": "..." },
  "issue": { "number": 17, "title": "...", "body": "..." },
  "diff": { "file": "/tmp/pr-review-42.diff", "lines": 350 }
}
```

If the script exits non-zero, report the error to the user and stop.

## Step 2: Gather Remaining Context

Using the script output, fetch each piece of context below and hold it in memory. **Do not spawn sub-agents until all variables are populated.**

- **`ISSUE_BODY`** — Available directly from `issue.body` in the script output.
- **`PRD_CONTENT`** — Find the feature name from the PRD Reference field in the issue body. Read `docs/PRD/<feature-name>.md`. If the file does not exist, set `PRD_CONTENT = "PRD not found — file docs/PRD/<feature-name>.md is missing."` and note the discrepancy.
- **`ADR_CONTENTS`** — Find the Architectural Decisions section in the issue body. For each referenced ADR, read `docs/ADR/<NNNN>-<slug>.md` and concatenate with a `--- ADR: <filename> ---` header. If no ADRs are referenced, set `ADR_CONTENTS = "No ADRs referenced in this issue."`
- **`PR_DIFF`** — Read the diff file from the path in the script output. The diff excludes lock files and generated artifacts. If the diff is large, pass it in full to sub-agents. Do not truncate — truncation causes missed findings.

## Step 3: Spawn Six Parallel Sub-Agent Reviewers

**In a single message, invoke the Agent tool six times in parallel — one call per reviewer.** Do not call them sequentially.

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

### Agent 2 — Test Scenario Compliance

Scope instruction:
```
Evaluate this PR exclusively for compliance with the test scenarios prescribed in the issue. Check:
(1) Find the "Test Scenarios" section in the issue body. It contains a table of scenarios per acceptance criterion, each with Input/Setup, Action, and Expected Result columns
(2) For every scenario in that table, find the corresponding automated test in the diff. Trace each scenario to a specific test function — name both the scenario and the test
(3) Verify the test actually exercises the described Input/Setup, performs the described Action, and asserts the described Expected Result. A test that only partially covers a scenario (e.g. checks the action but not the expected result) is incomplete
(4) Check that the PR description includes a "Test Coverage" mapping section showing which test covers which criterion/scenario

Any prescribed test scenario with no corresponding test is a FAIL.
Any scenario where the test does not match the prescribed Input/Action/Expected Result is a FAIL.
If the issue has no Test Scenarios section, return WARN and note the gap — then fall back to checking that each acceptance criterion has at least one test.
```

---

### Agent 3 — Test Coverage & Quality

Scope instruction:
```
Evaluate this PR independently for test coverage quality — go beyond the prescribed scenarios and assess whether the tests are actually sufficient. Check both end-to-end/integration test sufficiency and general test quality.

PART A — E2E & Integration Test Coverage:
(1) Identify every user-facing behavior and external integration introduced or modified in the diff. For each, determine whether an end-to-end or integration test exercises it through the real system boundary (HTTP endpoint, CLI invocation, message queue, database, file system, external API). A unit test that validates internal logic does not satisfy this — the test must prove the feature works as a user or upstream system would interact with it
(2) Check that e2e/integration tests hit real services and real infrastructure, not mocks or stubs. Tests that mock the database, API client, or service layer at the integration level provide false confidence and are a FAIL
(3) For each acceptance criterion, ask: "If this feature were deployed, would these tests have caught a regression before a user did?" If the answer is no — because the test only checks internal functions, or only checks the happy path, or mocks away the integration point — flag the gap
(4) Look for missing UAT-style scenarios: user workflows that span multiple steps or components (e.g., create → retrieve → update → verify), error recovery paths a user would encounter (invalid input, service unavailable, partial failure), and boundary conditions at system edges (empty responses from external APIs, timeouts, malformed payloads)
(5) Any acceptance criterion with no e2e or integration test exercising it through a real system boundary is a FAIL. Any e2e/integration test that mocks away the integration point it claims to test is a FAIL

PART B — Test Quality:
(1) Read the production code in the diff. Identify all code paths, branches, error handlers, and edge cases. Flag any untested paths
(2) Evaluate test meaningfulness: would the tests catch regressions? Look for tests with no meaningful assertions, tests that assert implementation details rather than behavior, or tests that would pass even if the production code returned hardcoded values
(3) Evaluate assertion quality: do tests verify behavioral correctness (correct output, correct data, correct side effects) or just "no error thrown"? For features that generate or transform data, are there assertions on output quality — format conformance, grounding (outputs traceable to inputs), semantic correctness?
(4) Do the test file structure, naming conventions, and assertion patterns match the existing codebase style visible in the diff

Any acceptance criterion lacking e2e/integration coverage is a FAIL. Any production code path with no test coverage is a WARN. Tests that mock the integration point they claim to exercise are a FAIL. Tests with no meaningful assertions are a FAIL.
```

---

### Agent 4 — Task Compliance Reviewer

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

### Agent 5 — Architecture & Standards Reviewer

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

### Agent 6 — Performance & Reliability Reviewer

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

Replace `<number>`, `<title>`, `<ISSUE_BODY>`, `<PRD_CONTENT>`, `<ADR_CONTENTS>`, and `<PR_DIFF>` with the full text collected in Steps 1-2. Inline the content — do not reference it abstractly.

## Step 4: Check CI

```bash
gh pr checks <number>
```

All checks must pass. If checks are still running, use `gh run watch` to wait for completion rather than sleep-based polling. Do not merge while anything is pending or failing.

Distinguish a code failure from an infrastructure flake — note the difference explicitly if relevant.

## Step 5: Aggregate Results and Decide

Collect the six agent reports. Build a decision table:

| Reviewer | Verdict | Blocking | Warnings |
|---|---|---|---|
| Security | | | |
| Test Scenario Compliance | | | |
| Test Coverage & Quality | | | |
| Task Compliance | | | |
| Architecture & Standards | | | |
| Performance & Reliability | | | |
| CI | | — | — |

**Merge if and only if**: all six agents returned PASS (zero FAILs, zero WARNs) AND CI is passing.

**Request changes if**: any agent returned FAIL or WARN, OR CI is failing with a code failure (not an infra flake).

**Wait**: if CI is still pending, use `gh run watch` to wait for completion before deciding.

Warnings block merge just like failures. WARNs typically indicate tech debt, missing edge-case coverage, or code quality issues that are straightforward to fix — letting them through accumulates debt that is cheapest to resolve right now, before the PR is merged. Include the full WARN findings in the review comment so the author knows exactly what to address.

---

### All PASS, CI green → merge

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

### Any FAIL or WARN → request changes

```bash
gh pr comment <number> --body "$(cat <<'EOF'
## Review

[One sentence summary — e.g. "Needs changes: 2 blocking findings across security and test coverage." Include both FAILs and WARNs in the count.]

### Sub-Agent Results

| Reviewer | Verdict | Blocking | Warnings |
|---|---|---|---|
| Security | ✅ PASS / ❌ FAIL / ⚠️ WARN | N | N |
| Test Scenario Compliance | | | |
| Test Coverage & Quality | | | |
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

Resolve all FAIL and WARN items above and the PR will be ready to merge.
EOF
)"
```

Do not merge a PR with any open FAIL or WARN findings. Do not approve without merging — either it's ready and gets merged, or it gets blocked with clear feedback.

## Failure Modes

- **Script exits non-zero**: report the error message to the user and stop. Common causes: no open PR on current branch, PR is a draft, no linked issue, linked issue doesn't exist.
- **PRD not found**: report the discrepancy between the feature name in the issue and what exists in `docs/PRD/`
- **Agent returns malformed output**: re-invoke that single agent with a correction prompt before proceeding; do not guess at its verdict
