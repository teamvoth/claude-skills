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

Include the full diff in each agent's context block as the `{{DIFF}}` value.

## Evaluating results

Build a decision table from the three reports:

| Reviewer | Verdict | Blocking | Warnings |
|---|---|---|---|
| Code Quality & Architecture | | | |
| Task Adherence | | | |
| Test Quality & Coverage | | | |

### All PASS → proceed to PR

### Any WARN (no FAIL) → fix or note

Fix warnings that are clearly correct and low-risk. For subjective warnings or those requiring significant rework, note them in the PR description as known observations. Then proceed to PR.

### Any FAIL → fix and re-review

For each blocking finding:
1. **Read** the finding. Identify the specific file, line, and condition the reviewer flagged.
2. **Understand** why it was flagged — what invariant or requirement does it violate?
3. **Fix** the issue. If the fix is non-obvious, follow the [debugging-protocol.md](debugging-protocol.md) — state your hypothesis, make a single-variable change.
4. **Verify the specific finding** — re-check the exact condition the reviewer described. Can you still reproduce the problem? If yes, the fix is incomplete — return to step 3.
5. **Run the full test suite** to confirm no regressions.

After all findings are individually verified as resolved, re-run all three review sub-agents on the updated diff. If new FAILs appear, fix those too. Do not loop more than twice — if findings persist after two fix rounds, report remaining issues to the user as a blocker.
