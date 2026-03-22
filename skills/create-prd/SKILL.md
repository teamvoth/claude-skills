---
name: create-prd
description: Use this skill when the user asks to "create a PRD", "write a PRD", "document this feature", "create a product requirements document", or wants to formalize a feature before implementation. Also invoke when the user has finished a grill-me session and is ready to capture the outcome as a document.
version: 1.0.0
---

# Create PRD

Produce a durable Product Requirements Document for a feature. The PRD is written to survive implementation changes — it describes *what* the product does and *why*, not *how* it's built. It will be read by future-you and referenced by Claude during implementation and task breakdown.

## Step 1: Scan the Codebase

Before asking a single question, explore the codebase to understand the current state of affairs. Look for:
- Existing features related to what the user wants to build
- Patterns, conventions, and constraints already in place
- Anything that would create dependencies, conflicts, or opportunities

Do this silently. Don't summarize it to the user. Use it to ask smarter questions and avoid gaps — you're looking for the things the user might not think to mention because they seem obvious.

If there is no codebase (greenfield), skip this step.

## Step 2: Check Session State

Look at the current conversation. Has a `grill-me` session already been completed for this feature? Signs it has: the user answered a series of probing questions, goals and out-of-scope items were discussed, and a summary was confirmed.

- **If yes**: skip Step 3 entirely. You already have what you need.
- **If no**: proceed to Step 3.

## Step 3: Grill the User

Run a focused interview to build complete shared understanding. Follow the same approach as the `grill-me` skill — start with the most important unknown, follow the thread, and don't stop until there are no gaps.

For a PRD specifically, make sure you surface:
- **The core goal** — what problem does this solve, and for whom?
- **Success criteria** — how will you know it's working?
- **Out of scope** — what are you explicitly *not* building? This is as important as what you are building.
- **Edge cases and constraints** — what breaks the happy path? What are the hard limits?
- **Functional behavior** — what does the product actually do, step by step, from the user's perspective?

When you have a complete picture, summarize it back and get explicit confirmation before writing anything.

## Step 4: Write the PRD

Create the file at `docs/PRD/<feature-name>.md` where `feature-name` is a short kebab-case slug derived from the feature (e.g. `user-authentication.md`, `bulk-export.md`).

Use this exact template:

---

```markdown
# PRD: [Feature Name]

## Overview

[One to two paragraphs. What is this feature, why does it exist, and what problem does it solve? Write for someone who has no context — your future self six months from now.]

## Goals

- [What does success look like from a user/product perspective?]
- [Each goal should be outcome-oriented, not implementation-oriented]
- [...]

## Out of Scope

The following are explicitly not part of this feature:

- [...]
- [...]

## User Stories / Functional Requirements

[Describe what the product does from the user's perspective. Use present tense. Stay implementation-agnostic — describe behavior, not mechanism. Each requirement should hold true regardless of what stack or architecture is used.]

**[Logical grouping if needed]**

- The system [does X when Y]
- Users can [accomplish Z]
- [...]

## Acceptance Criteria

[Specific, testable conditions that define "done". These should be verifiable by a human tester or by Claude. Written as assertions — either true or false.]

- [ ] [Condition that must be true]
- [ ] [Condition that must be true]
- [ ] [...]

## Open Questions

[Unresolved decisions or known unknowns at time of writing. It's fine to ship a PRD with open questions — capture them so they don't get lost.]

- [Question or decision not yet made]
- [...]
```

---

Write with precision. Vague requirements create ambiguous implementations. If something isn't clear enough to be testable, it isn't done yet.

## Step 5: Get Approval and Commit

Show the completed PRD to the user. Ask: "Does this look right? I'll commit it once you confirm."

Wait for explicit confirmation. Then:

1. Create the feature branch and push it:
```bash
git checkout -b feature/<feature-name>
git push -u origin feature/<feature-name>
```

2. Commit the PRD to the feature branch:
```bash
git add docs/PRD/<feature-name>.md
git commit -m "docs: add PRD for <feature name>"
git push
```

If `docs/PRD/` doesn't exist yet, create it. Don't create a README or any other files — just the PRD.

The feature branch is the home for everything related to this feature — the PRD, all implementation PRs, and the final merge into main all happen here. Do not commit to main.
