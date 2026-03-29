---
name: prd-to-issues
description: Decomposes a PRD into executable GitHub issues by identifying architectural decisions (recorded as ADRs), creating vertical slices mapped to acceptance criteria, and writing detailed issue bodies with test scenarios and dependencies. Triggers on "break down a PRD", "create issues from a PRD", "turn the PRD into tasks", or any request to move from planning to execution.
argument-hint: "[feature-name]"
version: 3.0.0
allowed-tools: Bash(gh *), Bash(git *), Read, Glob, Grep
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

Extract the `feature-name` from the filename (e.g. `user-authentication.md` -> `user-authentication`). The GitHub label will be `<feature-name>` and the branch will be `feature/<feature-name>`.

## Step 2: Identify Approach Decisions

Before decomposing into issues, identify decisions that will shape how the work gets sliced. These are choices where picking the wrong approach means rework — not just in one issue, but across multiple.

Scan the PRD and codebase for:
- **Implementation strategies** — e.g. single LLM call vs. decomposed multi-call pipeline, sync vs. async processing
- **Technology choices** implied but not stated — e.g. the PRD says "persist data" but doesn't say how
- **Integration approaches** — how the new feature connects to existing code
- **Patterns that constrain multiple issues** — e.g. "use SQLite for storage" affects every issue that touches data
- Existing ADRs in `docs/ADR/` that apply — new decisions must not contradict them without explicitly superseding

For each decision: **would choosing wrong here be expensive to reverse?** If yes, it must be resolved before slicing.

### Resolve decisions with the user

If you identified high-impact approach decisions, invoke `/grill-me` to work through them. Focus on the specific decision points, the tradeoffs, and how each choice affects the issue decomposition.

**Do not proceed to Step 3 until all approach decisions are resolved.**

If no new approach decisions exist (feature follows existing patterns exactly), skip the grilling and note this.

## Step 3: Capture Architectural Decisions as ADRs

Convert resolved decisions from Step 2 into ADRs. Each decision that constrains multiple issues, would be costly to reverse, or isn't obvious from requirements alone gets its own ADR.

Determine the next ADR number by listing `docs/ADR/` and incrementing from the highest existing number (start at `0001` if empty). Create `docs/ADR/` if it doesn't exist.

Create one file per decision at `docs/ADR/<NNNN>-<slug>.md` using the template at [templates/adr-template.md](templates/adr-template.md).

Key principles:
- **One decision per ADR.** If you're tempted to write "and also", that's two ADRs.
- **Write for the implementor.** Be concrete — name specific libraries, patterns, file paths, and conventions.
- **Record the why, not just the what.** The context is what makes it valuable.
- **Consequences must be honest.** State tradeoffs to prevent future agents from "optimizing" away deliberate choices.

Commit all ADRs to the feature branch before creating issues:

```bash
git add docs/ADR/
git commit -m "docs: add ADRs for <feature-name>"
git push
```

## Step 4: Decompose Into Slices

Each issue should be one vertical slice — a coherent, user-facing increment that can be implemented, tested, and reviewed independently. The default mapping is **one issue per acceptance criterion**. Combine criteria only when inseparable. Split only when large enough to be its own meaningful increment.

Order issues by logical implementation sequence. If an issue depends on code from a prior issue, it must come after it.

Think through each issue before creating any — gaps in the issue body become gaps in the implementation. Every ADR that constrains an issue must be referenced in that issue's body.

## Step 5: Create Issues

Ensure the feature label exists:

```bash
gh label create <feature-name> --color "#0075ca" --description "Issues for the <feature-name> feature" 2>/dev/null || true
```

Create issues one at a time, in sequence. You need each issue number before writing the next, because later issues may reference earlier ones as dependencies. Use the template at [templates/issue-body-template.md](templates/issue-body-template.md) for each issue body.

```bash
gh issue create \
  --title "<concise title describing the slice>" \
  --body "<filled issue body>" \
  --label "<feature-name>"
```

## Step 6: Report Back

```
Created N issues for <feature-name>:

#1  <title>
#2  <title> (depends on #1)
#3  <title> (depends on #2)
...

Architectural decisions recorded:
- ADR-NNNN: <title>
(or: No new ADRs — feature follows existing patterns.)

All issues are labeled `<feature-name>` and target the `feature/<feature-name>` branch.
To begin implementation, run: /work-issue <feature-name>
```

## Failure Modes

- **PRD has no acceptance criteria**: stop and tell the user — suggest running `/create-prd` first
- **PRD has open questions that would block implementation**: surface them before creating issues
- **`gh` not authenticated**: tell the user to run `gh auth login`
- **Feature branch doesn't exist**: create it with `git checkout -b feature/<feature-name> && git push -u origin feature/<feature-name>`
