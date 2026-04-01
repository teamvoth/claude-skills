---
name: create-prd
description: Produces a Product Requirements Document for a feature by conducting a user interview (or using a completed grill-me session) and writing a structured PRD. Triggers on "create a PRD", "write a PRD", "document this feature", or when formalizing a feature before implementation.
argument-hint: "[feature-name]"
version: 2.1.0
allowed-tools: Bash(git *), Read, Glob, Grep, Agent
---

# Create PRD

Produce a durable Product Requirements Document for a feature. The PRD describes *what* the product does and *why*, not *how* it's built. It will be referenced by Claude during implementation and task breakdown.

## Step 1: Scan the Codebase

Before asking a single question, explore the codebase to understand the current state. Look for:
- Existing features related to what the user wants to build
- Patterns, conventions, and constraints already in place
- Anything that would create dependencies, conflicts, or opportunities

Do this silently. Don't summarize it to the user. Use it to ask smarter questions and avoid gaps.

If there is no codebase (greenfield), skip this step.

## Step 2: Check Session State

Has a `grill-me` session already been completed for this feature in the current conversation? Signs it has: the user answered a series of probing questions, goals and out-of-scope items were discussed, and a summary was confirmed.

- **If yes**: skip Step 3. You already have what you need.
- **If no**: proceed to Step 3.

## Step 3: Grill the User

Run a focused interview to build complete shared understanding. Follow the same approach as the `grill-me` skill — start with the most important unknown, follow the thread, don't stop until there are no gaps.

For a PRD specifically, surface:
- **The core goal** — what problem does this solve, and for whom?
- **Success criteria** — how will you know it's working?
- **Out of scope** — what are you explicitly *not* building?
- **Edge cases and constraints** — what breaks the happy path? What are the hard limits?
- **Functional behavior** — what does the product actually do, step by step, from the user's perspective?
- **Quality attributes** — what non-functional properties matter and why? Ask about each only when relevant to the feature: performance constraints, security boundaries, reliability requirements, modularity expectations, observability needs, testability concerns. Don't run down a generic checklist — reason about which attributes actually matter given what the feature does, then ask targeted questions about those.

When you have a complete picture, summarize it back and get explicit confirmation before writing.

## Step 4: Write the PRD

Create the file at `docs/PRD/<feature-name>.md` where `feature-name` is a short kebab-case slug (e.g. `user-authentication.md`, `bulk-export.md`).

Use the template at [templates/prd-template.md](templates/prd-template.md). Write with precision — vague requirements create ambiguous implementations. If something isn't clear enough to be testable, it isn't done yet.

If `docs/PRD/` doesn't exist yet, create it.

## Step 5: Get Approval and Commit

Show the completed PRD to the user. Ask: "Does this look right? I'll commit it once you confirm."

Wait for explicit confirmation. Then:

1. Create the feature branch and push it:
```bash
git checkout -b feature/<feature-name>
git push -u origin feature/<feature-name>
```

2. Commit the PRD:
```bash
git add docs/PRD/<feature-name>.md
git commit -m "docs: add PRD for <feature name>"
git push
```

The feature branch is the home for everything related to this feature. Do not commit to main.
