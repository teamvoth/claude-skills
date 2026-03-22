---
name: feature-pr
description: Use this skill when the user asks to "create the feature PR", "open a PR for the feature", "ship this feature", "submit the feature for review", or wants to create a pull request from a feature branch into main after all issues are complete. Invoke with a feature name (e.g. `/feature-pr user-authentication`) or from within the feature branch.
version: 1.0.0
---

# Feature PR

Create a pull request from the feature branch into main. Run all quality gates first — all issues closed, no outstanding PRs against the feature branch, PRD fully implemented as verified against the actual codebase, integration tests covering the full user journey, code clean. Open the PR regardless of gate results, documenting any blockers clearly in the body. Merging to main is a human decision enforced by GitHub branch protection.

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

Read the PRD in full. Then examine the codebase against every acceptance criterion — not as a paperwork exercise, but as a genuine code review.

For each acceptance criterion:
- Find the code that implements it
- Verify the implementation satisfies the intent of the criterion, not just its literal wording
- Note any criterion that is absent, partially implemented, or contradicts the PRD's goals

Closed issues mean work was submitted. This step confirms the work reflects what the PRD required. They are different checks.

Pass: every criterion is verifiably implemented. Fail: note exactly which criteria and what's missing.

### Gate 4: Integration Test Coverage and Code Quality

Pull the latest feature branch:

```bash
git checkout feature/<feature-name>
git pull
```

**Integration coverage:** Evaluate whether the test suite covers the full user journey described in the PRD — not just the sum of individual issue tests. The slices were implemented independently; verify they work together. Look for:
- End-to-end coverage of user journeys in the PRD's functional requirements
- Error and edge cases that span multiple slices
- Gaps that only appear when the feature is considered as a whole

**Run the full test suite.** All tests must pass.

**Code quality:**
- Run the formatter — must be clean
- Run the linter — zero warnings, zero errors

Pass: tests pass, coverage complete, code clean. Fail: note exactly what failed.

## Step 3: Open the PR

Open the PR regardless of gate results. The body reflects what passed and what didn't.

```bash
gh pr create \
  --title "<Feature Name>" \
  --body "$(cat <<'EOF'
## Summary

[2-3 sentences describing what this feature delivers and why it exists.]

## PRD

`docs/PRD/<feature-name>.md`

## Issues

- Closes #N — [title]
- Closes #N — [title]

## Quality Gates

- [x/[ ]] All feature issues closed
- [x/[ ]] No outstanding PRs against feature branch
- [x/[ ]] All PRD acceptance criteria verified against codebase
- [x/[ ]] Integration test coverage confirmed across full user journey
- [x/[ ]] Full test suite passing
- [x/[ ]] Lint and formatting clean

[If any gates failed, add a section here:]
## Blockers

### [Category]
[Specific description of what failed and what's needed to resolve it.]
EOF
)" \
  --base main \
  --label "<feature-name>"
```

Report the PR URL and summarize any open blockers so the user knows what needs attention before the PR can be merged.

## Failure Modes

- **PRD not found**: stop immediately — cannot validate without it
- **Feature branch not on remote**: report it, do not create the PR
- **CI failing on feature branch**: include in the gate results; note whether it looks like a code failure or an infrastructure flake
