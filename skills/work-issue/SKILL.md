---
name: work-issue
description: Use this skill when the user asks to "work the next issue", "execute the next task", "implement the next issue", "work issue <N>", or wants Claude to autonomously pick up and implement the next ready GitHub issue. Optionally scoped to a feature with a label. This skill is designed for hands-off autonomous execution.
version: 1.0.0
---

# Work Issue

Autonomously implement the next ready GitHub issue. Read the issue, read the PRD, scan the codebase, implement the work, verify quality, and open a PR — with no human involvement unless a blocker is hit.

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

## Step 4: Implement

Create the working branch off the feature branch:

```bash
git checkout feature/<feature-name>
git pull
git checkout -b task/<issue-number>
```

Implement the changes required to satisfy the acceptance criteria. Stay within scope — the Out of Scope section is a hard boundary, not a suggestion. If the issue says "does not include X," do not include X even if it seems like a natural addition.

Write code that fits the conventions identified in Step 3. Don't introduce new patterns when existing ones will do.

**For complex implementations** (multiple modules, significant logic, or unfamiliar territory), consider splitting the work across subagents by component or concern area. Each subagent should receive:
- The relevant subset of the issue's acceptance criteria
- The codebase context from Step 3 (conventions, patterns, relevant files)
- Clear boundaries on what files it should create or modify

Use your judgment on when this is warranted — a single-file change doesn't need delegation, but a multi-module feature benefits from it.

## Step 5: Write Tests and Verify Quality

This step is not optional. A PR without passing tests does not get opened.

**Tests:**
- Write automated end-to-end functional tests that exercise every behavior listed in the acceptance criteria against real services (not mocks)
- Tests must validate **behavioral correctness** — not just "did it run" but "did it produce the right output." For features that generate or transform data, assert on output quality: format conformance, grounding (outputs traceable to inputs), and semantic correctness
- Write tests for every explicit error case and edge case described in the issue

**Run all tests locally — this is a gate, not a suggestion:**
- Identify the project's test runner and test commands (check `package.json`, `Makefile`, `pyproject.toml`, `Cargo.toml`, or equivalent)
- If the project has external dependencies (databases, message queues, cloud services, etc.), set them up before running tests. Use Docker Compose, local services, or whatever the project documents. If nothing is documented, check for `docker-compose.yml`, `.env.example`, or setup scripts. If dependencies cannot be set up, flag this as a blocker — do not skip the tests
- Run the **full** integration/e2e test suite, not just the tests you wrote. Your changes must not break existing tests
- If any test fails, fix the issue and re-run. Do not open a PR with failing tests
- Include the test run output (or a summary) in your PR description so reviewers can see the suite passed

**Code quality:**
- Run the formatter — code must be clean
- Run the linter — zero warnings, zero errors
- Fix anything that flags before proceeding

All of these requirements are non-negotiable. A clean implementation that fails a test or lint check is not a complete implementation.

## Step 6: Open the PR

Push the branch and open a PR targeting the feature branch:

```bash
git push -u origin task/<issue-number>
gh pr create \
  --title "<concise title matching the issue title>" \
  --body "$(cat <<'EOF'
Closes #<issue-number>

[Only include this section if there are implementation decisions worth noting:]
## Implementation Notes

- [Notable decision and why it was made]
- [...]
EOF
)" \
  --base feature/<feature-name> \
  --label "<feature-name>"
```

Keep the PR description minimal. The issue carries the spec. Only surface implementation decisions that are non-obvious or that future Claude should know when reading the code.

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
