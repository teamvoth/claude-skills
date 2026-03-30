# Review Phase Instructions

Spawn three review sub-agents **in a single message, in parallel** — one call per reviewer. Do not call them sequentially.

## Building each agent's prompt

Each agent prompt has three parts in order:
1. The shared preamble (below)
2. The agent's specific scope instruction (below)
3. The context block (below), with all placeholders replaced by actual content

## Shared Review Preamble

Include this verbatim at the start of every agent's prompt:

```
!`cat "${CLAUDE_SKILL_DIR}/prompts/review-preamble.md"`
```

## Agent 1 — Code Quality & Architecture

Scope instruction:
```
!`cat "${CLAUDE_SKILL_DIR}/prompts/reviewer-quality.md"`
```

## Agent 2 — Task Adherence

Scope instruction:
```
!`cat "${CLAUDE_SKILL_DIR}/prompts/reviewer-adherence.md"`
```

## Agent 3 — Test Quality & Coverage

Scope instruction:
```
!`cat "${CLAUDE_SKILL_DIR}/prompts/reviewer-tests.md"`
```

## Context Block

Append this to every agent prompt, with placeholders replaced:

```
!`cat "${CLAUDE_SKILL_DIR}/templates/review-context-block.md"`
```

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
3. **Fix** the issue. If the fix is non-obvious, follow the debugging protocol below — state your hypothesis, make a single-variable change.
4. **Verify the specific finding** — re-check the exact condition the reviewer described. Can you still reproduce the problem? If yes, the fix is incomplete — return to step 3.
5. **Run the full test suite** to confirm no regressions.

After all findings are individually verified as resolved, re-run all three review sub-agents on the updated diff. If new FAILs appear, fix those too. Do not loop more than twice — if findings persist after two fix rounds, report remaining issues to the user as a blocker.

## Debugging Protocol

When a fix is non-obvious, follow this approach:

!`cat "${CLAUDE_SKILL_DIR}/prompts/debugging-protocol.md"`
