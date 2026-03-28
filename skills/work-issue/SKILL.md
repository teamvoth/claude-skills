---
name: work-issue
description: Use this skill when the user asks to "work the next issue", "execute the next task", "implement the next issue", "work issue <N>", or wants Claude to autonomously pick up and implement the next ready GitHub issue. Optionally scoped to a feature with a label. This skill is designed for hands-off autonomous execution.
version: 2.0.0
---

# Work Issue

Autonomously implement the next ready GitHub issue. Read the issue, read the PRD, scan the codebase, delegate implementation and review to specialized sub-agents, fix any findings, and open a PR — with no human involvement unless a blocker is hit.

## Step 1: Find the Next Ready Issue

If a feature label was provided (e.g. `/work-issue <feature-name>`), filter to issues with that label. Otherwise, look at all open issues.

```bash
# With feature label
gh issue list --label "<feature-name>" --state open --json number,title,body,labels

# Without
gh issue list --state open --json number,title,body,labels
```

For each open issue, check its **Dependencies** section. A dependency is unresolved if the referenced issue is still open:

```bash
gh issue view <dep-issue-number> --json state
```

Select the **lowest-numbered open issue where all dependencies are closed**. If no issues are ready (all have unresolved dependencies), report what's blocked:

```
No issues are ready to work.

Blocked:
  #3 <title> — waiting on #1 (still open)
  #4 <title> — waiting on #2 (still open)
```

Do not proceed until there is a ready issue.

## Step 2: Read the Issue and PRD

Read the full issue body. Every section matters:
- **What This Accomplishes** — the intent
- **Acceptance Criteria** — the exact conditions that must be true when you're done
- **Out of Scope** — hard boundaries, do not cross them
- **Technical Notes** — hints about relevant code areas
- **Dependencies** — already resolved, but useful for understanding what exists
- **Definition of Done** — the checklist you must satisfy before opening a PR

Then read the referenced PRD (`docs/PRD/<feature-name>.md`). The PRD is the authoritative source of feature intent. Use it to resolve ambiguities in the issue and to ensure your implementation fits within the broader feature.

If the issue has an **Architectural Decisions** section, read every referenced ADR in `docs/ADR/`. These are binding constraints — they document deliberate choices with specific reasoning. Do not deviate from them. If an ADR conflicts with what seems like a better approach, follow the ADR and note the tension in your PR description.

## Step 3: Scan the Codebase

Before writing any code, understand the terrain. Spawn an **Explore subagent** to investigate the codebase and report back. This keeps research out of the main context window.

The subagent prompt should include the full issue body and ask it to find and report:
- Code directly relevant to what the issue asks you to build (file paths, key types, function signatures)
- Existing patterns and conventions to follow (naming, structure, error handling style)
- The testing framework and patterns used — with concrete examples of existing test files
- Anything that could conflict with or be impacted by the changes
- Relevant configuration, environment variables, or service dependencies

**Wait for the subagent to return before proceeding.** Use its findings as the input to Step 4 — do not re-scan the codebase yourself.

## Step 4: Collect Context Into Named Variables

Before spawning the implementation sub-agent, assemble all context into named variables. **Do not proceed to Step 5 until all variables are populated.**

- **`ISSUE_BODY`** — the full issue body from Step 2
- **`PRD_CONTENT`** — the full PRD content from Step 2
- **`ADR_CONTENTS`** — concatenated ADR contents (or "No ADRs referenced in this issue.")
- **`CODEBASE_FINDINGS`** — the Explore subagent's full report from Step 3
- **`FEATURE_NAME`** — the feature label/name
- **`ISSUE_NUMBER`** — the issue number

## Step 5: Spawn the Implementation Sub-Agent

Create the working branch first — do this yourself, not the sub-agent:

```bash
git checkout feature/<feature-name>
git pull
git checkout -b task/<issue-number>
```

Then spawn a single **implementation sub-agent** (using the Agent tool). This agent does all coding and test writing. It receives the full context and works autonomously.

### Implementation Agent Prompt

Include this prompt verbatim, with the context block appended:

```
You are an implementation agent. You will receive a GitHub issue, PRD, ADRs, and codebase analysis. Your job is to implement the issue completely — production code and tests — following the conventions identified in the codebase analysis.

## What to implement

Read the acceptance criteria in the issue. Implement exactly what is required — nothing more. The Out of Scope section is a hard boundary, not a suggestion.

## How to implement

- Write code that fits the conventions described in the codebase findings. Don't introduce new patterns when existing ones will do.
- Stay within the scope of the acceptance criteria. If the issue says "does not include X," do not include X.
- For complex implementations (multiple modules, significant logic), you may split work across your own sub-agents by component. Each should receive the relevant subset of acceptance criteria and clear file boundaries.

## Tests

Write tests from the issue's Test Scenarios section:
- Implement every scenario as an automated test. These are specifications, not suggestions — do not skip, simplify, or reinterpret them
- Tests must run against real services (not mocks) and validate behavioral correctness — not just "did it run" but "did it produce the right output"
- If the issue has no Test Scenarios section, write tests that cover every acceptance criterion

## Code quality

- Run the formatter — code must be clean
- Run the linter — zero warnings, zero errors
- Fix anything that flags

## When you are done

Report back with:
1. A list of every file you created or modified
2. A brief summary of how each acceptance criterion was addressed
3. The test commands to run (test runner, any setup needed)
4. Any decisions you made that were not obvious from the issue

Do not open a PR. Do not push. Just implement and report.
```

### Context Block (append to the implementation agent prompt)

```
---
ISSUE NUMBER: <ISSUE_NUMBER>
FEATURE NAME: <FEATURE_NAME>

ISSUE BODY:
<ISSUE_BODY>

PRD CONTENT:
<PRD_CONTENT>

ARCHITECTURAL DECISION RECORDS:
<ADR_CONTENTS>

CODEBASE ANALYSIS:
<CODEBASE_FINDINGS>
---
```

**Wait for the implementation agent to return before proceeding.**

## Step 6: Run Tests Locally

This is a gate the main agent owns — do not delegate it.

- Identify the project's test runner and test commands (check `package.json`, `Makefile`, `pyproject.toml`, `Cargo.toml`, or equivalent)
- If the project has external dependencies (databases, message queues, cloud services, etc.), set them up before running tests. Use Docker Compose, local services, or whatever the project documents
- Run the **full** integration/e2e test suite, not just the tests the implementation agent wrote. The changes must not break existing tests
- If any test fails, fix the issue and re-run. Do not proceed with failing tests
- Save the test output for the PR description

## Step 7: Spawn Three Review Sub-Agents in Parallel

**In a single message, invoke the Agent tool three times in parallel — one call per reviewer.** Do not call them sequentially.

Each agent prompt must include three parts in order:
1. The shared output format preamble (below)
2. The agent's specific scope instruction (below)
3. The full context block (below)

---

### Shared Output Format Preamble

Include this text verbatim at the start of every review agent's prompt:

```
You are a specialized code reviewer. You will receive the full diff of changes on the current branch, the GitHub issue being implemented, the PRD for this feature, and any ADRs that apply. Your job is to evaluate one specific dimension only — do not comment outside your scope.

Return your findings in EXACTLY this format:

## [AGENT NAME] Review

**Verdict**: PASS | FAIL | WARN
(PASS = no issues; FAIL = blocking issues that must be fixed before merge; WARN = non-blocking observations worth noting)

**Findings**:
[If PASS: one sentence confirming what you checked and that it passed.]
[If FAIL or WARN: numbered list. For each finding: (1) what the issue is, (2) where — file name and line number if applicable, (3) why it matters, (4) suggested fix.]

**Blocking Issues**: N | **Warnings**: N

Do not summarize the PR beyond what is needed to explain your findings.
```

---

### Agent 1 — Code Quality & Architecture Reviewer

Scope instruction:
```
Evaluate this diff exclusively for code quality and architectural issues. Check:
(1) ADR compliance: for each ADR provided, verify the implementation follows the decision. Deviations are a FAIL even if the code works — ADRs capture deliberate choices whose reasoning must be preserved
(2) Existing patterns: does the code follow the conventions visible in the codebase (naming, file organization, error handling style, module structure)
(3) Code quality: dead code, unused imports, variables declared but never used, unreachable branches, unnecessary complexity
(4) Naming consistency: are names clear, accurate, and consistent with the surrounding codebase
(5) Security: hardcoded secrets, injection vulnerabilities, missing input validation at system boundaries
(6) Performance: obvious algorithmic inefficiencies, N+1 query patterns, unnecessary repeated work, resource leaks
(7) Error handling: are errors from external calls caught and handled; does the code fail safely

Only flag items with clear impact — do not flag micro-optimizations or stylistic preferences.
If no ADRs were provided, state this and skip that check.
```

---

### Agent 2 — Task Adherence Reviewer

Scope instruction:
```
Evaluate this diff exclusively for compliance with the issue and PRD. Check:
(1) For each acceptance criterion in the issue, trace it to the specific code that implements it — "it says it does X" is not evidence, find the code that does X
(2) Scope: does the diff contain any changes not required by the acceptance criteria, even if they look like improvements? Extra work is a FAIL
(3) PRD alignment: does the implementation reflect the intent described in the PRD, or does anything contradict the PRD's goals or out-of-scope boundaries
(4) Definition of done: evaluate each checklist item in the issue's Definition of Done section against the diff
(5) Out of Scope violations: check the Out of Scope section in the issue — any implementation that crosses those boundaries is a FAIL

Any unmet acceptance criterion is a FAIL. Any out-of-scope change is a FAIL. Any Definition of Done item not satisfied is a FAIL.
```

---

### Agent 3 — Test Quality & Coverage Reviewer

Scope instruction:
```
Evaluate this diff for test quality and coverage. Check prescribed scenario compliance, independent coverage quality, and end-to-end/integration test sufficiency.

PART A — Test Scenario Compliance:
(1) Find the "Test Scenarios" section in the issue body. It contains scenarios per acceptance criterion, each with Input/Setup, Action, and Expected Result
(2) For every scenario, find the corresponding automated test in the diff. Trace each scenario to a specific test function — name both the scenario and the test
(3) Verify the test actually exercises the described Input/Setup, performs the described Action, and asserts the described Expected Result. A test that only partially covers a scenario is incomplete
(4) Any prescribed test scenario with no corresponding test is a FAIL. Any scenario where the test does not match the prescribed Input/Action/Expected Result is a FAIL
(5) If the issue has no Test Scenarios section, return WARN and note the gap — then fall back to checking that each acceptance criterion has at least one test

PART B — E2E & Integration Test Coverage:
(1) Identify every user-facing behavior and external integration introduced or modified in the diff. For each, determine whether an end-to-end or integration test exercises it through the real system boundary (HTTP endpoint, CLI invocation, message queue, database, file system, external API). A unit test that validates internal logic does not satisfy this — the test must prove the feature works as a user or upstream system would interact with it
(2) Check that e2e/integration tests hit real services and real infrastructure, not mocks or stubs. Tests that mock the database, API client, or service layer at the integration level provide false confidence and are a FAIL
(3) For each acceptance criterion, ask: "If this feature were deployed, would these tests have caught a regression before a user did?" If the answer is no — because the test only checks internal functions, or only checks the happy path, or mocks away the integration point — flag the gap
(4) Look for missing UAT-style scenarios: user workflows that span multiple steps or components (e.g., create → retrieve → update → verify), error recovery paths a user would encounter (invalid input, service unavailable, partial failure), and boundary conditions at system edges (empty responses from external APIs, timeouts, malformed payloads)
(5) Any acceptance criterion with no e2e or integration test exercising it through a real system boundary is a FAIL. Any e2e/integration test that mocks away the integration point it claims to test is a FAIL

PART C — Test Quality (independent of prescribed scenarios):
(1) Read the production code in the diff. Identify all code paths, branches, error handlers, and edge cases. Flag any untested paths
(2) Evaluate test meaningfulness: would the tests catch regressions? Look for tests with no meaningful assertions, tests that assert implementation details rather than behavior, or tests that would pass even if the production code returned hardcoded values
(3) Evaluate assertion quality: do tests verify behavioral correctness (correct output, correct data, correct side effects) or just "no error thrown"? For features that generate or transform data, are there assertions on output quality — format conformance, grounding (outputs traceable to inputs), semantic correctness?
(4) Do the test file structure, naming conventions, and assertion patterns match the existing codebase style

Any acceptance criterion lacking e2e/integration coverage is a FAIL. Any production code path with no test coverage is a WARN. Tests that mock the integration point they claim to exercise are a FAIL. Tests with no meaningful assertions are a FAIL.
```

---

### Context Block (append to every review agent prompt)

Generate the diff of changes on the current branch vs the feature branch:

```bash
git diff feature/<feature-name>...HEAD
```

Then include this context block in every review agent prompt:

```
---
ISSUE NUMBER: <ISSUE_NUMBER>
FEATURE NAME: <FEATURE_NAME>

ISSUE BODY:
<ISSUE_BODY>

PRD CONTENT:
<PRD_CONTENT>

ARCHITECTURAL DECISION RECORDS:
<ADR_CONTENTS>

DIFF:
<the full diff output>
---
```

Replace all placeholders with the full text collected in Step 4. Inline the content — do not reference it abstractly.

## Step 8: Evaluate Results and Fix

Collect the three review reports. Build a decision table:

| Reviewer | Verdict | Blocking | Warnings |
|---|---|---|---|
| Code Quality & Architecture | | | |
| Task Adherence | | | |
| Test Quality & Coverage | | | |

### If all three returned PASS

Proceed to Step 9.

### If any returned WARN (but no FAIL)

Evaluate each warning. Fix warnings that are clearly correct and low-risk to address. For warnings that are subjective or would require significant rework, note them in the PR description as known observations. Then proceed to Step 9.

### If any returned FAIL

For each blocking finding:
1. Read the finding carefully — understand what the reviewer flagged and why
2. Fix the issue. Use the reviewer's suggested fix as a starting point, but verify it makes sense in context
3. After fixing, re-run the full test suite to confirm nothing broke

After fixing all blocking findings, re-run the three review sub-agents on the updated diff to confirm the fixes resolved the issues. If new FAILs appear, fix those too. Do not loop more than twice — if findings persist after two fix rounds, report the remaining issues to the user as a blocker.

## Step 9: Open the PR

Push the branch and open a PR targeting the feature branch:

```bash
git add <specific files>
git commit -m "<message>"
git push -u origin task/<issue-number>
gh pr create \
  --title "<concise title matching the issue title>" \
  --body "$(cat <<'EOF'
Closes #<issue-number>

## Test Coverage

| Acceptance Criterion | Test Scenario | Test Function |
|---|---|---|
| [criterion from issue] | [scenario from issue] | [test function name] |
| ... | ... | ... |

## Test Results

[Summary of test run — pass/fail counts, full suite confirmation]

[Only include this section if there are implementation decisions worth noting:]
## Implementation Notes

- [Notable decision and why it was made]

[Only include this section if review sub-agents returned warnings:]
## Review Observations

- [Warning and why it was accepted rather than fixed]
EOF
)" \
  --base feature/<feature-name> \
  --label "<feature-name>"
```

## Handling Blockers

If at any point you hit something that prevents full implementation — an ambiguity that can't be resolved from the issue and PRD, a conflict with existing code, acceptance criteria that are impossible as written, or a missing dependency not captured in the issue — do the following:

**1. Create a draft PR with the blocker explained:**

```bash
gh pr create \
  --title "[BLOCKED] <issue title>" \
  --body "$(cat <<'EOF'
Closes #<issue-number>

## Blocked

[Clear explanation of what the blocker is. Be specific — what did you find, what did you try, what decision needs to be made?]

## What's needed to unblock

[Exactly what a human needs to do or decide to allow this to proceed.]
EOF
)" \
  --base feature/<feature-name> \
  --draft
```

**2. Apply the `blocked` label to the issue** (create it if it doesn't exist):

```bash
gh label create "blocked" --color "#d93f0b" --description "Pending human input before work can continue" 2>/dev/null || true
gh issue edit <issue-number> --add-label "blocked"
```

**3. Report to the user** what the blocker is and what they need to decide.

Do not make up answers to unresolvable ambiguities. Do not proceed past a genuine blocker. The draft PR and blocked label are the handoff mechanism.
