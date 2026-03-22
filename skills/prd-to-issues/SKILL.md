---
name: prd-to-issues
description: Use this skill when the user asks to "break down a PRD", "create issues from a PRD", "turn the PRD into tasks", "create GitHub issues for this feature", or is ready to move from planning to execution after a PRD exists. Also invoke after create-prd completes if the user wants to proceed immediately to task breakdown.
version: 2.0.0
---

# PRD to Issues

Read a PRD and create a set of GitHub issues that decompose it into executable vertical slices. Before creating issues, identify and record architectural decisions as ADRs — these serve as durable reference for both humans and agents throughout implementation.

Each issue is a self-contained work order intended to be executed by Claude with minimal human involvement — Claude will be given an issue and expected to implement it, write tests, and open a PR autonomously.

## Step 1: Read and Understand the PRD

Locate the PRD. If the user specified a feature name, look at `docs/PRD/<feature-name>.md`. If not, list the files in `docs/PRD/` and ask which one to use.

Read the entire PRD before doing anything else. Pay close attention to:
- **Acceptance criteria** — these map directly to issues
- **Out of scope** — you'll need to reflect this at the issue level
- **Functional requirements** — use these to add context and technical hints to each issue
- **Open questions** — flag any that would block implementation

Extract the `feature-name` from the filename (e.g. `user-authentication.md` → `user-authentication`). The GitHub label will be `<feature-name>` and the branch will be `feature/<feature-name>`.

## Step 2: Identify the Slices

Each issue should be one vertical slice — a coherent, user-facing increment that can be implemented, tested, and reviewed independently. The default mapping is **one issue per acceptance criterion**. Combine criteria into a single issue only when they are inseparable (i.e. one cannot be implemented without the other). Split a criterion into multiple issues only when it's large enough to be its own meaningful increment.

Order the issues by logical implementation sequence. If an issue depends on code or behavior from a prior issue, it must come after it.

Think through each issue before creating any. You're writing work orders for an autonomous implementor — gaps in the issue body become gaps in the implementation.

## Step 3: Capture Architectural Decisions

Before creating issues, scan the codebase and the PRD for decisions that will shape implementation. An architectural decision is any choice that:

- **Constrains multiple issues** — e.g. "use SQLite for storage" affects every issue that touches data
- **Would be costly to reverse later** — e.g. choosing an auth strategy, a data model shape, an API style
- **Isn't obvious from the requirements alone** — e.g. the PRD says "persist data" but doesn't say how

To identify decisions, examine the codebase for:
- Existing patterns and conventions that the feature must follow (framework, ORM, test style, directory structure)
- Integration points where the new feature connects to existing code
- Technology choices implied but not stated by the PRD

Also check `docs/ADR/` for existing ADRs. New decisions must not contradict existing ones without explicitly superseding them.

### When to create ADRs

- If the feature introduces **no new architectural decisions** (e.g. it follows existing patterns exactly), skip ADR creation and note this in Step 6's summary. Not every feature needs ADRs.
- If you identify decisions, present them to the user for confirmation before writing files. The user may adjust, add, or remove decisions.

### Writing ADRs

Determine the next ADR number by listing `docs/ADR/` and incrementing from the highest existing number (start at `0001` if the directory is empty). Create `docs/ADR/` if it doesn't exist.

Create one file per decision at `docs/ADR/<NNNN>-<slug>.md` using this template:

```markdown
# ADR-<NNNN>: <Decision Title>

## Status

Accepted

## Context

[What is the situation that requires a decision? What forces are at play — technical constraints, product requirements, existing patterns, team preferences? Be specific enough that someone reading this in six months understands why the question came up at all.]

## Decision

[State the decision clearly and directly. "We will use X" or "Y will be implemented as Z." No hedging.]

## Consequences

### Benefits
- [What becomes easier, safer, or more consistent as a result of this decision]

### Tradeoffs
- [What becomes harder, more constrained, or ruled out. Every decision has tradeoffs — name them honestly.]

## References

- PRD: `docs/PRD/<feature-name>.md`
- [Any other relevant docs, ADRs, or external resources]
```

Key principles for good ADRs:
- **One decision per ADR.** If you're tempted to write "and also", that's two ADRs.
- **Write for the implementor.** These will be read by agents executing issues. Be concrete — name specific libraries, patterns, file paths, and conventions.
- **Record the why, not just the what.** The decision itself is one line. The context is what makes it valuable.
- **Consequences must be honest.** If a tradeoff exists, state it. This prevents future agents from "optimizing" away a deliberate choice because they don't understand the reasoning.

### Committing ADRs

Commit all ADRs to the feature branch before creating issues:

```bash
git add docs/ADR/
git commit -m "docs: add ADRs for <feature-name>"
git push
```

## Step 4: Create the GitHub Label

Before creating issues, ensure the feature label exists:

```bash
gh label create <feature-name> --color "#0075ca" --description "Issues for the <feature-name> feature" 2>/dev/null || true
```

The `|| true` handles the case where the label already exists.

## Step 5: Create Issues in Order

Create issues one at a time, in sequence. You need each issue number before writing the next, because later issues may reference earlier ones as dependencies.

Use this body template for each issue:

```markdown
## What This Accomplishes

[One short paragraph. What user-facing capability does this slice deliver? Write it so Claude can understand the intent without reading the entire PRD.]

## PRD Reference

[Link to the PRD file in the repo, e.g.: `docs/PRD/<feature-name>.md`]

Full context, goals, and constraints for this feature are documented there.

## Acceptance Criteria

[Copy the specific acceptance criteria from the PRD that this issue satisfies. These are the exact conditions that must be true for this issue to be considered complete.]

- [ ] [Criterion]
- [ ] [Criterion]

## Out of Scope

The following are explicitly not part of this issue:

- [What this issue does NOT do — be specific. Prevents Claude from over-implementing.]
- [Functionality covered by other issues in this feature]
- [Anything deferred to a future feature]

## Architectural Decisions

[List any ADRs that govern this issue's implementation. If none apply, write "None." These are binding constraints — the implementor must follow them.]

- `docs/ADR/<NNNN>-<slug>.md` — [one-line summary of how it affects this issue]

## Technical Notes

[Optional. Relevant files, patterns, or constraints Claude should be aware of. Point to existing code when it provides useful context. Leave blank if the implementation approach is straightforward from the acceptance criteria alone.]

## Dependencies

[List any issues that must be merged before this one can begin, e.g. "Depends on #12". If none, write "None."]

## Definition of Done

Before opening a PR, confirm:

- [ ] All acceptance criteria above are satisfied
- [ ] Automated user acceptance tests cover every functional behavior in the acceptance criteria
- [ ] Automated tests cover all explicit error cases and edge cases described above
- [ ] All tests pass
- [ ] No functionality outside the scope of this issue is added or modified
- [ ] PR targets the `feature/<feature-name>` branch
```

Create each issue with:

```bash
gh issue create \
  --title "<concise title describing the slice>" \
  --body "<filled issue body>" \
  --label "<feature-name>"
```

Capture the issue number from the output of each `gh issue create` command. You'll need it to populate dependency references in subsequent issues.

## Step 6: Report Back

Once all issues are created, output a summary:

```
Created N issues for <feature-name>:

#1  <title>
#2  <title> (depends on #1)
#3  <title> (depends on #2)
...

Architectural decisions recorded:
- ADR-NNNN: <title>
- ADR-NNNN: <title>
(or: No new ADRs — feature follows existing patterns.)

All issues are labeled `<feature-name>` and target the `feature/<feature-name>` branch.
To begin implementation, direct Claude to: "execute the next open issue labeled <feature-name>"
```

## Failure Modes to Handle

- **PRD has no acceptance criteria**: stop and tell the user — issues can't be created without them. Suggest running `/create-prd` first.
- **PRD has open questions that would block implementation**: surface them before creating issues and ask how to resolve them.
- **`gh` not authenticated**: tell the user to run `gh auth login` and try again.
- **Feature branch doesn't exist**: create it with `git checkout -b feature/<feature-name> && git push -u origin feature/<feature-name>` before creating issues, since PRs will target it.
