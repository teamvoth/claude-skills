---
name: setup-repo
description: Use this skill when the user asks to "set up the repo", "configure github", "set up branch protection", "configure repo settings", "initialize the repo workflow", or wants to enforce the standard development workflow on a GitHub repository. Safe to run on new or existing repos — idempotent, enforces minimums without removing extra configuration.
version: 1.0.0
---

# Setup Repo

Configure a GitHub repository to enforce the standard feature development workflow. This skill is idempotent — it ensures required settings are in place without disturbing anything extra. Safe to run on a new repo or an existing one.

## What Gets Configured

- **Repo merge settings**: squash merge enabled, rebase merge enabled, merge commits disabled, auto-delete head branches on merge
- **`main` branch protection**: no direct pushes, 1 required approval, all conversations resolved, required status checks (confirmed by user)
- **`feature/*` branch protection via Ruleset**: no direct pushes, no force pushes

## Step 1: Identify the Repo

Detect the current repo's GitHub remote:

```bash
gh repo view --json nameWithOwner
```

If not in a GitHub repo or `gh` is not authenticated, stop and tell the user to run `gh auth login`.

## Step 2: Detect CI Workflows

Scan for existing GitHub Actions workflow files:

```bash
ls .github/workflows/*.yml .github/workflows/*.yaml 2>/dev/null
```

For each workflow file found, extract the job names — these become the required status check names in GitHub:

```bash
# For each workflow file, extract job keys
grep -A1 "^jobs:" .github/workflows/<file>.yml | grep -v "^jobs:" | grep "^\s*\w" | awk -F: '{print $1}' | xargs
```

Present the detected checks to the user:

```
Found the following CI jobs that can be required as status checks:

  • test (from ci.yml)
  • lint (from ci.yml)
  • build (from build.yml)

Should I require all of these on main before merging? Or specify which ones to include/exclude.
```

Wait for confirmation before proceeding. If no workflows exist, note that required status checks will be skipped — the user can re-run this skill after adding workflows.

## Step 3: Configure Repo Merge Settings

```bash
gh api repos/{owner}/{repo} \
  --method PATCH \
  --field allow_squash_merge=true \
  --field allow_merge_commit=false \
  --field allow_rebase_merge=true \
  --field delete_branch_on_merge=true
```

This enables squash merging (for task→feature PRs) and rebase merging (for feature→main PRs), disables standard merge commits to keep history clean, and auto-deletes head branches after merge.

## Step 4: Configure Main Branch Protection

```bash
gh api repos/{owner}/{repo}/branches/main/protection \
  --method PUT \
  --input - <<EOF
{
  "required_status_checks": {
    "strict": true,
    "contexts": [<confirmed check names as JSON array>]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "require_last_push_approval": false
  },
  "restrictions": null,
  "required_conversation_resolution": true,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
```

If no status checks were confirmed, set `"required_status_checks": null` instead.

## Step 5: Configure Feature Branch Ruleset

Use GitHub's Rulesets API to protect all `feature/*` branches by pattern — this works for branches that don't exist yet:

```bash
# Check if the ruleset already exists
EXISTING=$(gh api repos/{owner}/{repo}/rulesets --jq '.[] | select(.name == "feature-branch-protection") | .id' 2>/dev/null)

if [ -n "$EXISTING" ]; then
  # Update existing ruleset
  METHOD="PUT"
  ENDPOINT="repos/{owner}/{repo}/rulesets/$EXISTING"
else
  # Create new ruleset
  METHOD="POST"
  ENDPOINT="repos/{owner}/{repo}/rulesets"
fi

gh api "$ENDPOINT" \
  --method "$METHOD" \
  --input - <<EOF
{
  "name": "feature-branch-protection",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/feature/**"],
      "exclude": []
    }
  },
  "rules": [
    { "type": "non_fast_forward" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false
      }
    }
  ]
}
EOF
```

This enforces that all `feature/<name>` branches require a PR — no direct pushes — and disallows force pushes. No approval requirement on feature branches since those PRs are reviewed by `pr-review` before merging.

## Step 6: Report

```
✅ Repo configured for the feature development workflow.

Merge settings:
  • Squash merge: enabled (task → feature)
  • Rebase merge: enabled (feature → main)
  • Merge commits: disabled
  • Auto-delete branches after merge: enabled

main branch protection:
  • Direct pushes: blocked
  • Required approvals: 1
  • Conversation resolution: required
  • Required status checks: [list or "none configured"]

feature/* branch protection (Ruleset):
  • Direct pushes: blocked
  • Force pushes: blocked
```

## Failure Modes

- **`gh` not authenticated**: tell the user to run `gh auth login`
- **No admin access to the repo**: the API calls will fail with 403 — report this and tell the user they need admin rights
- **`main` branch doesn't exist yet**: skip Step 4 and note it; re-run after the first commit
- **Rulesets not available** (e.g. free plan repos may have limitations): fall back to reporting what couldn't be configured and suggest using classic branch protection for feature branches manually
