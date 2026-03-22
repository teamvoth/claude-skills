---
name: pr-review
description: Use this skill when the user asks to "review a PR", "review this pull request", "check the PR", "evaluate the PR", or wants to review and potentially merge an open pull request. Also use when the user wants to verify a PR meets all requirements before merging. Can be invoked with a PR number (e.g. `/pr-review 42`) or without to review the most recent open PR on the current branch.
version: 1.0.0
---

# PR Review

Evaluate a pull request against the issue it implements, the PRD it belongs to, and the codebase standards. If everything passes and CI is green, merge it. If not, leave a detailed review comment explaining exactly what needs to change.

## Step 1: Identify the PR

If a PR number was provided, use it. Otherwise, find the most recent open PR on the current feature branch:

```bash
gh pr list --state open --json number,title,headRefName,baseRefName
```

Fetch the full PR details:

```bash
gh pr view <number> --json number,title,body,headRefName,baseRefName,files,reviews,statusCheckRollup
```

Extract the linked issue number from the PR body (`Closes #N`). If no issue is linked, flag it — every PR in this workflow must link to an issue.

## Step 2: Read the Full Context

Read in this order:

1. **The linked issue** — `gh issue view <number> --json title,body`
   - Acceptance criteria (what must be true)
   - Out of scope (what must not be present)
   - Definition of done checklist

2. **The PRD** — find the reference in the issue body, read `docs/PRD/<feature-name>.md`
   - Understand the broader feature intent
   - Use it to evaluate whether the implementation fits the product, not just the literal acceptance criteria

3. **Architectural Decisions** — if the issue has an Architectural Decisions section, read every referenced ADR in `docs/ADR/`
   - These are binding constraints the implementation must follow
   - Note the reasoning in each ADR — it explains *why* the constraint exists

4. **The changed files** — `gh pr diff <number>`
   - Read every changed file
   - Understand what was added, modified, or removed

## Step 3: Evaluate the PR

Work through each dimension. For each, make a binary pass/fail determination with specific evidence.

### Acceptance Criteria
For each criterion in the issue: is it satisfied? Trace a path from the criterion to the code that implements it — don't take the PR description's word for it.

### Scope
Does the implementation stay within the issue's out of scope boundaries? Flag any changes not covered by the acceptance criteria, even if they look like improvements.

### Test Coverage
- Automated user acceptance tests cover every functional behavior in the acceptance criteria
- Tests cover every explicit error case and edge case in the issue
- Tests would actually fail if the implementation were broken
- Test patterns match the existing codebase conventions

### Code Quality
- Follows codebase conventions and patterns
- Formatting is clean
- Zero lint warnings or errors
- No dead code, unused imports, or inconsistent naming

### ADR Compliance
If ADRs are referenced in the issue, does the implementation follow them? Check each referenced ADR and verify the code adheres to the decision. Flag any deviation — even if the code works, violating an ADR means the implementation is incorrect because it undermines a deliberate architectural choice.

### PRD Alignment
Does the implementation reflect the intent of the PRD? Does anything contradict the PRD's goals or out of scope?

## Step 4: Check CI

```bash
gh pr checks <number>
```

All checks must pass. If checks are still running, wait and recheck. Do not merge while anything is pending or failing.

Distinguish a code failure from an infrastructure flake — note the difference explicitly if relevant.

## Step 5: Decision

### Everything passes → merge

```bash
gh pr merge <number> --squash --delete-branch
gh issue close <issue-number>
```

Report:
```
PR #<N> merged and branch deleted.
Issue #<N> closed.
```

### Anything fails → request changes

```bash
gh pr review <number> --request-changes --body "$(cat <<'EOF'
## Review

[One sentence summary — e.g. "Needs changes: test coverage is incomplete and one acceptance criterion is not satisfied."]

### ❌ [Failed dimension]

[Specific, actionable description. Reference file names and line numbers. "Tests are missing" is not enough — "There is no test for the case where X" is.]

### ✅ [Passing dimension]

[Brief confirmation.]

---

Resolve the above and the PR will be ready to merge.
EOF
)"
```

Do not merge a PR with any open issues. Do not approve without merging — either it's ready and gets merged, or it gets blocked with clear feedback.

## Failure Modes

- **No linked issue**: comment asking for an issue link, do not review further
- **PRD not found**: report the discrepancy between the feature name in the issue and what exists in `docs/PRD/`
- **Draft PR**: do not merge; comment that it needs to be marked ready for review first
