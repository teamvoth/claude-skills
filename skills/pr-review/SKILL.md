---
name: pr-review
description: Use this skill when the user asks to "review a PR", "review this pull request", "check the PR", "evaluate the PR", or wants to review and potentially merge an open pull request. Also use when the user wants to verify a PR meets all requirements before merging. Can be invoked with a PR number (e.g. `/pr-review 42`) or without to review the most recent open PR on the current branch.
version: 3.5.0
allowed-tools: Bash(bash *collect-context.sh*), Bash(gh *), Read, Agent
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
- **`PR_DIFF`** — Read the diff file from the path in the script output. The diff excludes lock files and generated artifacts.

## Step 2.5: Prepare Per-Reviewer Context

Each reviewer gets a tailored context block — not the full dump. Prepare filtered context for each:

| Reviewer | Diff | PRD | ADRs | Issue |
|---|---|---|---|---|
| **Security** | Production code only | Compressed: quality attributes + out-of-scope | Relevant ADRs only | Full |
| **Test Scenario Compliance** | Test code + referenced production code | Not needed | Not needed | Full |
| **Test Coverage & Quality** | Test code + production code | Compressed: acceptance criteria + quality attributes | Not needed | Full |
| **Task Compliance** | Full diff | Full PRD | All ADRs | Full |
| **Architecture & Standards** | Production code + config files | Compressed: quality attributes + out-of-scope | All ADRs | Full |
| **Performance & Reliability** | Production code only | Compressed: quality attributes only | Not needed | Full |

**Filtering the diff:** Split by file path. Production code = non-test source files. Test code = files matching test naming conventions for the project (e.g., `*_test.go`, `*.test.ts`, `test_*.py`, `tests/`). Config = build configs, CI files, manifests. If uncertain whether a file is test or production, include it in both contexts.

**Compressing the PRD:** Extract only the sections listed in the table. "Compressed" means dropping Overview, Goals, User Stories/Functional Requirements, and Open Questions — keeping Acceptance Criteria, Out of Scope, and Quality Attributes as applicable.

## Step 3: Spawn Six Parallel Sub-Agent Reviewers

**In a single message, invoke the Agent tool six times in parallel — one call per reviewer.** Do not call them sequentially.

Each agent prompt must include three parts in order:
1. The shared output format preamble (below)
2. The agent's specific scope instruction (below)
3. The per-reviewer context block prepared in Step 2.5

---

### Shared Output Format Preamble

Include this text verbatim at the start of every agent's prompt:

```
You are a specialized code reviewer. You will receive a complete PR diff, the GitHub issue it implements, the PRD for this feature, and any ADRs that apply. Your job is to evaluate one specific dimension only — do not comment outside your scope.

Return your findings in EXACTLY this format:

## [AGENT NAME] Review

**Verdict**: PASS | FAIL | WARN | REDESIGN
(PASS = no issues; FAIL = blocking issues that must be fixed before merge; WARN = non-blocking observations worth noting; REDESIGN = the implementation reveals a fundamental design problem that cannot be fixed by changing code in this PR — the issue, ADR, or PRD needs to be revisited)

**Findings**:
[If PASS: one sentence confirming what you checked and that it passed.]
[If FAIL or WARN: numbered list. For each finding: (1) what the issue is, (2) where — file name and line number if applicable, (3) why it matters.]
[If REDESIGN: (1) what the architectural problem is, (2) which design artifact (issue, ADR, or PRD) needs revisiting, (3) what specific question or decision needs to be reconsidered, (4) why a code fix is insufficient.]

**Blocking Issues**: N | **Warnings**: N

Do not summarize the PR beyond what is needed to explain your findings.
```

---

### Agent 1 — Security Reviewer

Scope instruction:
```
Evaluate this PR exclusively for security vulnerabilities across three domains: traditional application security, LLM application risks, and agentic system risks.

DOMAIN 1 — Traditional Application Security (OWASP Top 10):
(1) Injection: SQL, command, template, path traversal
(2) Broken authentication and authorization: are protected resources actually protected, are permission checks present
(3) XSS, IDOR, security misconfiguration, sensitive data exposure
(4) Hardcoded secrets, credentials, API keys, tokens, or environment values in code or tests
(5) Input validation: is user-supplied data validated before use
(6) Use of components with known vulnerabilities

DOMAIN 2 — LLM Application Risks (OWASP LLM Top 10):
(7) Prompt injection: is untrusted content (user input, retrieved documents, external data) concatenated into prompts without sanitization or delimiter isolation
(8) Sensitive information disclosure: could the LLM leak secrets, PII, or system prompts through its outputs
(9) Improper output handling: is LLM output passed to downstream systems (SQL, shell, HTML, APIs) without validation or encoding
(10) Excessive agency: are tool permissions broader than necessary, are destructive operations available without confirmation gates
(11) Supply chain: are third-party models, plugins, MCP servers, or prompt templates loaded without integrity verification

DOMAIN 3 — Agentic System Risks (OWASP Agentic Top 10 + Rule of Two):
(12) Rule of Two violation: does any code path allow an agent to simultaneously [A] process untrusted input, [B] access sensitive data, AND [C] take external actions? If all three properties are present without a human-in-the-loop gate, this is a FAIL. Any two of the three is acceptable
(13) Tool misuse: can tools be chained in sequences that produce harmful outcomes even though each individual call is authorized (e.g., read file + send email = data exfiltration)
(14) Memory/context poisoning: can untrusted content write to persistent agent memory, RAG indexes, or shared state that affects future sessions
(15) Identity and privilege: does the agent operate with its own broad permissions rather than the requesting user's scoped permissions
(16) Cascading failures: can one agent's bad output propagate unchecked through a multi-agent pipeline

If the diff contains no user-facing input, LLM integration, or agentic behavior, state which domains were checked and which were not applicable, and return PASS.
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
(2) Check that e2e/integration tests hit real services and real infrastructure by default. Tests that mock the database, API client, or service layer at the integration level provide false confidence and are a FAIL. Exception: contract tests or stubs are acceptable for paid, rate-limited, or destructive external APIs (e.g., payment processors, email senders) — but only when the test includes a comment documenting why a real call is impractical and what contract the stub enforces. Mocking an internal service or database remains a FAIL regardless
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
Evaluate this PR exclusively for architectural and code quality issues.

Before running the checks below, identify what quality dimensions are most relevant for the code in this diff. Is it handling untrusted input (security priority)? Is it on a hot path (performance priority)? Is it a straightforward CRUD operation (pattern compliance priority)? State your calibration in one sentence, then apply the checks with proportionate rigor.

Check:
(1) ADR compliance: for each ADR provided, verify the implementation follows the decision. Deviations are a FAIL even if the code works — ADRs capture deliberate choices whose reasoning must be preserved
(2) Existing patterns: does the code follow the conventions visible in the diff context (naming, file organization, error handling style, module structure)
(3) Code quality: dead code, unused imports, variables declared but never used, unreachable branches
(4) Naming consistency: are names clear, accurate, and consistent with the surrounding codebase

(5) Module boundaries: is the public API surface minimal (no internal types leaked)? Do dependencies flow in one direction (no circular imports)? Are boundaries placed at natural seams? Flag abstractions that exist for only a single call site — they add indirection without reuse value.

If no ADRs were provided, state this and skip that check.
```

---

### Agent 6 — Performance & Reliability Reviewer

Scope instruction:
```
Evaluate this PR exclusively for performance and reliability issues. Focus disproportionately on code paths that actually matter for performance — I/O boundaries, loops over collections, allocation-heavy paths. Do not flag theoretical performance issues in cold paths or admin-only code.

Check:
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

Replace each placeholder with the **per-reviewer filtered version** from Step 2.5 — not the full text. `<ISSUE_BODY>` is always full. `<PRD_CONTENT>`, `<ADR_CONTENTS>`, and `<PR_DIFF>` vary per reviewer as defined in the filtering table. Omit sections entirely (replace with "Not applicable for this review scope.") when the table shows "Not needed." Inline the content — do not reference it abstractly.

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

**Merge if and only if**: all six agents returned PASS (zero FAILs, zero WARNs, zero REDESIGNs) AND CI is passing.

**Escalate if**: any agent returned REDESIGN. Do not request changes or merge. Comment on the PR with the REDESIGN findings, identify which design artifact (issue, ADR, or PRD) needs revisiting, and report to the user. A REDESIGN means the review found a problem that cannot be resolved by changing the PR — the upstream design needs to change first.

**Request changes if**: any agent returned FAIL or WARN (and no REDESIGN), OR CI is failing with a code failure (not an infra flake).

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
