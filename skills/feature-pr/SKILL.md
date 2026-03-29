---
name: feature-pr
description: Creates a pull request from a feature branch into main after verifying all quality gates — closed issues, PRD acceptance criteria, test coverage, and code quality. Triggers on "create the feature PR", "open a PR for the feature", "ship this feature", or any request to finalize a feature.
argument-hint: "[feature-name]"
version: 2.0.0
allowed-tools: Bash(gh *), Bash(git *), Read, Glob, Grep
---

# Feature PR

Create a pull request from the feature branch into main. Run all quality gates first — all issues closed, no outstanding PRs against the feature branch, PRD fully implemented, integration tests covering the full user journey, code clean. Open the PR regardless of gate results, documenting any blockers clearly in the body. Merging to main is a human decision enforced by GitHub branch protection.

## Step 1: Identify the Feature

If a feature name was provided as an argument, use it. Otherwise infer from the current branch name. If neither is available, list feature branches and ask:

```bash
git branch -r | grep -v HEAD | sed 's/  origin\///' | grep -v main
```

Locate the PRD at `docs/PRD/<feature-name>.md`. If it doesn't exist, stop — this workflow requires a PRD.

## Step 2: Run the Quality Gates

Run all gates and collect results. Do not stop at the first failure — evaluate everything so the PR body captures the full picture.

### Gate 1: All Issues Closed

```bash
gh issue list --label "<feature-name>" --state open --json number,title
```

Pass: no open issues. Fail: list which are open.

### Gate 2: No Outstanding PRs Against the Feature Branch

```bash
gh pr list --base feature/<feature-name> --state open --json number,title,headRefName
```

Pass: no open PRs. Fail: list which are open.

### Gate 3: PRD Acceptance Criteria Verified Against Codebase

Read the PRD in full. Examine the codebase against every acceptance criterion — not as a paperwork exercise, but as a genuine code review.

For each criterion: find the code that implements it, verify the implementation satisfies the intent, note anything absent or partially implemented.

Pass: every criterion is verifiably implemented. Fail: note exactly which criteria and what's missing.

### Gate 4: Integration Test Coverage and Code Quality

```bash
git checkout feature/<feature-name>
git pull
```

**Integration coverage:** Evaluate whether the test suite covers the full user journey — not just the sum of individual issue tests. Look for end-to-end coverage, error cases spanning multiple slices, and gaps that only appear when the feature is considered as a whole.

**Run the full test suite.** All tests must pass.

**Code quality:** Run the formatter and linter — must be clean.

Pass: tests pass, coverage complete, code clean. Fail: note exactly what failed.

## Step 3: Open the PR

Open the PR regardless of gate results. Use [templates/feature-pr-body.md](templates/feature-pr-body.md) for the body structure.

```bash
gh pr create \
  --title "<Feature Name>" \
  --body "<filled PR body>" \
  --base main \
  --label "<feature-name>"
```

Report the PR URL and summarize any open blockers so the user knows what needs attention before merge.

## Failure Modes

- **PRD not found**: stop immediately — cannot validate without it
- **Feature branch not on remote**: report it, do not create the PR
- **CI failing on feature branch**: include in gate results; note whether it's a code failure or infrastructure flake
