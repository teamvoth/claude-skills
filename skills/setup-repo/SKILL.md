---
name: setup-repo
description: Configures a GitHub repository to enforce the standard feature development workflow — merge settings, branch protection, required status checks, and feature branch rulesets. Idempotent and safe for new or existing repos. Triggers on "set up the repo", "configure github", "set up branch protection", or any request to initialize repo workflow settings.
version: 2.0.0
allowed-tools: Bash(gh *), Bash(ls *), Bash(grep *), Read
---

# Setup Repo

Configure a GitHub repository to enforce the standard feature development workflow. Idempotent — ensures required settings are in place without disturbing anything extra.

## What Gets Configured

- **Repo merge settings**: squash merge enabled, rebase merge enabled, merge commits disabled, auto-delete head branches
- **`main` branch protection**: no direct pushes, 1 required approval, all conversations resolved, required status checks (confirmed by user)
- **`feature/*` branch protection via Ruleset**: no direct pushes, no force pushes

## Step 1: Identify the Repo

```bash
gh repo view --json nameWithOwner
```

If not in a GitHub repo or `gh` is not authenticated, stop and tell the user to run `gh auth login`.

## Step 2: Detect CI Workflows

```bash
ls .github/workflows/*.yml .github/workflows/*.yaml 2>/dev/null
```

For each workflow file, extract job names:

```bash
grep -A1 "^jobs:" .github/workflows/<file>.yml | grep -v "^jobs:" | grep "^\s*\w" | awk -F: '{print $1}' | xargs
```

Present detected checks and ask the user which to require on main. If no workflows exist, note that required status checks will be skipped.

## Step 3: Configure Repo Merge Settings

```bash
gh api repos/{owner}/{repo} \
  --method PATCH \
  --field allow_squash_merge=true \
  --field allow_merge_commit=false \
  --field allow_rebase_merge=true \
  --field delete_branch_on_merge=true
```

## Step 4: Configure Main Branch Protection

```bash
gh api repos/{owner}/{repo}/branches/main/protection \
  --method PUT \
  --input - <<'EOF'
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

If no status checks were confirmed, set `"required_status_checks": null`.

## Step 5: Configure Feature Branch Ruleset

```bash
# Check if the ruleset already exists
EXISTING=$(gh api repos/{owner}/{repo}/rulesets --jq '.[] | select(.name == "feature-branch-protection") | .id' 2>/dev/null)

if [ -n "$EXISTING" ]; then
  METHOD="PUT"
  ENDPOINT="repos/{owner}/{repo}/rulesets/$EXISTING"
else
  METHOD="POST"
  ENDPOINT="repos/{owner}/{repo}/rulesets"
fi

gh api "$ENDPOINT" \
  --method "$METHOD" \
  --input - <<'EOF'
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

## Step 6: Report

```
Repo configured for the feature development workflow.

Merge settings:
  - Squash merge: enabled (task -> feature)
  - Rebase merge: enabled (feature -> main)
  - Merge commits: disabled
  - Auto-delete branches after merge: enabled

main branch protection:
  - Direct pushes: blocked
  - Required approvals: 1
  - Conversation resolution: required
  - Required status checks: [list or "none configured"]

feature/* branch protection (Ruleset):
  - Direct pushes: blocked
  - Force pushes: blocked
```

## Failure Modes

- **`gh` not authenticated**: tell the user to run `gh auth login`
- **No admin access**: API calls fail with 403 — report this and tell the user they need admin rights
- **`main` branch doesn't exist yet**: skip Step 4 and note it; re-run after first commit
- **Rulesets not available** (free plan limitation): fall back to reporting what couldn't be configured
