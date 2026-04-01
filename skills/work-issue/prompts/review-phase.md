# Review Phase Instructions

Spawn three review sub-agents **in a single message, in parallel** — one call per reviewer. Do not call them sequentially.

## Building each agent's prompt

Each agent prompt has three parts in order:

1. Read [review-preamble.md](review-preamble.md) — include its full text verbatim
2. Read the agent's scope file (listed below) — include its full text verbatim
3. Append the context block using the [review-context-block.md](../templates/review-context-block.md) template, with all placeholders replaced by actual content

## Agent assignments

| Agent | Scope file |
|---|---|
| Code Quality & Architecture | [reviewer-quality.md](reviewer-quality.md) |
| Task Adherence | [reviewer-adherence.md](reviewer-adherence.md) |
| Test Quality & Coverage | [reviewer-tests.md](reviewer-tests.md) |

## Getting the diff

Generate the diff before spawning agents:

```bash
git diff feature/<feature-name>...HEAD
```

## Context preparation

Each reviewer gets a tailored context block — not the full dump. Before spawning agents, prepare filtered context for each reviewer:

| Reviewer | Diff | PRD | ADRs | Issue |
|---|---|---|---|---|
| **Code Quality & Architecture** | Production code only (non-test source files) | Compressed: acceptance criteria + out-of-scope + quality attributes only | All ADRs | Full |
| **Task Adherence** | Full diff | Full PRD | All ADRs | Full |
| **Test Quality & Coverage** | Test code + the production code referenced by tests | Compressed: acceptance criteria + quality attributes only | Not needed | Full |

**Filtering the diff:** Split by file path. Production code = non-test source files. Test code = files matching test naming conventions for the project (e.g., `*_test.go`, `*.test.ts`, `test_*.py`, `tests/`). If uncertain whether a file is test or production, include it in both reviewer contexts.

**Compressing the PRD:** Extract only the Acceptance Criteria, Out of Scope, and Quality Attributes sections. Drop Overview, Goals, User Stories/Functional Requirements, and Open Questions.

Use the [review-context-block.md](../templates/review-context-block.md) template for each, replacing placeholders with the filtered versions.

## Evaluating results

Build a decision table from the three reports:

| Reviewer | Verdict | Blocking | Warnings |
|---|---|---|---|
| Code Quality & Architecture | | | |
| Task Adherence | | | |
| Test Quality & Coverage | | | |

### All PASS → proceed to PR

### Any REDESIGN → stop and escalate

If any reviewer returns REDESIGN, do not attempt to fix the code. The review has identified a problem that lives in the design, not the implementation.

1. Push the current branch as-is
2. Open a **draft PR** with the REDESIGN findings in the body
3. Label the issue as needing redesign:
   ```bash
   gh label create "needs-redesign" --color "#7057ff" --description "Design artifact needs revisiting" 2>/dev/null || true
   gh issue edit <ISSUE_NUMBER> --add-label "needs-redesign"
   ```
4. Comment on the issue with the architectural concern and which design artifact (issue, ADR, or PRD) needs revisiting
5. Report to the user and stop — do not continue to the PR step

### Any WARN (no FAIL, no REDESIGN) → fix or note

Fix warnings that are clearly correct and low-risk. For subjective warnings or those requiring significant rework, note them in the PR description as known observations. Then proceed to PR.

### Any FAIL → fix and re-review

For each blocking finding:
1. **Read** the finding. Identify the specific file, line, and condition the reviewer flagged.
2. **Understand** why it was flagged — what invariant or requirement does it violate?
3. **Fix** the issue. If the fix is non-obvious, follow the [debugging-protocol.md](debugging-protocol.md) — state your hypothesis, make a single-variable change.
4. **Verify the specific finding** — re-check the exact condition the reviewer described. Can you still reproduce the problem? If yes, the fix is incomplete — return to step 3.
5. **Run the full test suite** to confirm no regressions.

After all findings are individually verified as resolved, re-run all three review sub-agents on the updated diff. If new FAILs appear, fix those too. Do not loop more than twice — if findings persist after two fix rounds, report remaining issues to the user as a blocker.
