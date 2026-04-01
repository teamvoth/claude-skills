---
name: work-issue
description: Autonomously implements the next ready GitHub issue. Picks up the lowest-numbered open issue with all dependencies resolved, reads the PRD and ADRs, scans the codebase, delegates implementation to a sub-agent, reviews the result, and opens a PR. Triggers on "work the next issue", "implement the next issue", "work issue <N>", or any request for autonomous issue execution. Optionally scoped to a feature label.
argument-hint: "[feature-label]"
version: 4.6.0
allowed-tools: Bash(bash *find-ready-issue.sh*), Bash(gh *), Bash(git *), Bash(cargo *), Read, Agent
---

# Work Issue

Autonomously implement the next ready GitHub issue. Each step below loads only the context it needs — read reference files only when you reach the step that uses them.

## Step 1: Find the Issue and Resolve Context

Run the issue finder script. If a feature label was provided, pass it as an argument.

```bash
bash "${CLAUDE_SKILL_DIR}/find-ready-issue.sh" [LABEL]
```

The script returns JSON with the issue body, feature name, PRD path (with existence check), ADR paths (with existence checks), and dependency audit trail. If it exits non-zero, report the blocked issues to the user and stop.

Extract **`ISSUE_NUMBER`**, **`ISSUE_BODY`**, and **`FEATURE_NAME`** from the script output.

**Checkout the feature branch before reading PRD/ADR files** — those files live on the feature branch, not main:

```bash
git checkout feature/<FEATURE_NAME>
git pull
```

Now resolve the remaining context:
- **`PRD_CONTENT`** — read the file at `context.prd.path`. If the file does not exist, set to `"PRD not found at <path>."` and note the discrepancy.
- **`ADR_CONTENTS`** — for each entry in `context.adrs`, read the file and concatenate with `--- ADR: <path> ---` headers. If no ADRs referenced, set to `"No ADRs referenced."`

## Step 2: Scan the Codebase

Spawn an **Explore subagent** with the full issue body. Ask it to find and report:
- Code directly relevant to what the issue asks you to build (file paths, key types, function signatures)
- Existing patterns and conventions (naming, structure, error handling style)
- Testing framework and patterns — with concrete examples of existing test files
- Anything that could conflict with or be impacted by the changes
- Relevant configuration, environment variables, or service dependencies

Save its report as **`CODEBASE_FINDINGS`**. Do not re-scan the codebase yourself.

## Step 3: Implement

Create the task branch from the feature branch (already checked out in Step 1):

```bash
git checkout -b task/<ISSUE_NUMBER>
```

Read [prompts/implementation-agent.md](prompts/implementation-agent.md). Spawn a single implementation sub-agent with that prompt, appending a context block built from the [templates/context-block.md](templates/context-block.md) template with `CODEBASE_FINDINGS` added after the ADR section.

Wait for the agent to return. Validate that its response includes a numbered task plan — if the first output is code without a plan, re-invoke with a correction prompt requiring the plan first.

## Step 4: Verify Tests

This is a gate you own — do not delegate it.

1. Identify the project's test runner (check `package.json`, `Makefile`, `pyproject.toml`, `Cargo.toml`, or equivalent)
2. Run the **full** test suite and capture the complete output
3. Parse the output for the final summary line (e.g., `test result: ok. 12 passed; 0 failed`). Extract the actual pass/fail counts
4. **Gate**: if fail count > 0, follow the debugging protocol at [prompts/debugging-protocol.md](prompts/debugging-protocol.md). Maximum 3 fix cycles before escalating to the user as a blocker using the [templates/blocked-pr-body.md](templates/blocked-pr-body.md) template
5. When all tests pass, save the **exact test runner summary line** for the PR body — not a paraphrase, the actual output

## Step 5: Review

Read [prompts/review-phase.md](prompts/review-phase.md) and follow its instructions to spawn three parallel review sub-agents and evaluate their results. The review phase file references its own sub-files for each reviewer's scope.

## Step 6: Open the PR

Push and open a PR targeting the feature branch. Read [templates/pr-body.md](templates/pr-body.md) for the body structure.

```bash
git add <specific files>
git commit -m "<message>"
git push -u origin task/<ISSUE_NUMBER>
gh pr create \
  --title "<concise title matching the issue title>" \
  --body "<filled PR body>" \
  --base feature/<FEATURE_NAME> \
  --label "<FEATURE_NAME>"
```

Fill in the test coverage table (mapping acceptance criteria → scenarios → test functions), test results, and any implementation notes or review observations.

## Handling Blockers

If you hit something that prevents full implementation — ambiguity not resolvable from the issue/PRD, code conflicts, impossible acceptance criteria, or missing dependencies:

1. **Create a draft PR** using the template at [templates/blocked-pr-body.md](templates/blocked-pr-body.md):

```bash
gh pr create \
  --title "[BLOCKED] <issue title>" \
  --body "<filled blocked PR body>" \
  --base feature/<FEATURE_NAME> \
  --draft
```

2. **Label the issue as blocked:**

```bash
gh label create "blocked" --color "#d93f0b" --description "Pending human input" 2>/dev/null || true
gh issue edit <ISSUE_NUMBER> --add-label "blocked"
```

3. **Report to the user** what the blocker is and what they need to decide.

Do not make up answers to unresolvable ambiguities. Do not proceed past a genuine blocker.
