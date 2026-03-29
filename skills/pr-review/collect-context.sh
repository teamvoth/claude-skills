#!/usr/bin/env bash
set -euo pipefail

# collect-context.sh — Deterministic PR discovery and validation for pr-review.
# Returns JSON with PR metadata, linked issue number, and path to the diff file.
# Exits non-zero with an error message on stderr for any validation failure.

usage() {
  echo "Usage: $0 [PR_NUMBER]" >&2
  echo "  If PR_NUMBER is omitted, finds the most recent open PR on the current branch." >&2
  exit 1
}

die() {
  echo "Error: $1" >&2
  exit 1
}

# --- Resolve PR number ---

if [[ $# -gt 1 ]]; then
  usage
fi

if [[ $# -eq 1 ]]; then
  PR_NUMBER="$1"
  # Validate it's a number
  [[ "$PR_NUMBER" =~ ^[0-9]+$ ]] || die "PR number must be a positive integer, got: $PR_NUMBER"
else
  BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || die "Not in a git repository."
  [[ "$BRANCH" != "main" && "$BRANCH" != "master" ]] || die "On $BRANCH branch — switch to a feature branch or provide a PR number."

  PR_NUMBER=$(gh pr list --state open --head "$BRANCH" --json number --jq '.[0].number // empty' 2>/dev/null) \
    || die "Failed to query GitHub for open PRs."
  [[ -n "$PR_NUMBER" ]] || die "No open PR found for branch '$BRANCH'."
fi

# --- Fetch PR details ---

PR_JSON=$(gh pr view "$PR_NUMBER" --json number,title,body,headRefName,baseRefName,isDraft 2>/dev/null) \
  || die "Failed to fetch PR #$PR_NUMBER. Does it exist?"

IS_DRAFT=$(echo "$PR_JSON" | jq -r '.isDraft')
[[ "$IS_DRAFT" != "true" ]] || die "PR #$PR_NUMBER is a draft. Mark it ready for review first."

PR_TITLE=$(echo "$PR_JSON" | jq -r '.title')
PR_BODY=$(echo "$PR_JSON" | jq -r '.body')
HEAD_REF=$(echo "$PR_JSON" | jq -r '.headRefName')
BASE_REF=$(echo "$PR_JSON" | jq -r '.baseRefName')

# --- Extract linked issue number ---

# Match "Closes #N", "Fixes #N", "Resolves #N" (case-insensitive, with optional colon)
ISSUE_NUMBER=$(echo "$PR_BODY" | grep -ioE '(closes|fixes|resolves):?\s*#[0-9]+' | head -1 | grep -oE '[0-9]+' || true)
[[ -n "$ISSUE_NUMBER" ]] || die "PR #$PR_NUMBER has no linked issue (expected 'Closes #N', 'Fixes #N', or 'Resolves #N' in the body)."

# Fetch the linked issue
ISSUE_JSON=$(gh issue view "$ISSUE_NUMBER" --json number,title,body 2>/dev/null) \
  || die "Linked issue #$ISSUE_NUMBER does not exist."

ISSUE_TITLE=$(echo "$ISSUE_JSON" | jq -r '.title')
ISSUE_BODY=$(echo "$ISSUE_JSON" | jq -r '.body')

# --- Fetch diff (excluding noise) ---

DIFF_FILE="/tmp/pr-review-${PR_NUMBER}.diff"

EXCLUDE_PATTERNS=(
  # Lock files
  'Cargo.lock'
  'package-lock.json'
  'yarn.lock'
  'pnpm-lock.yaml'
  'Gemfile.lock'
  'poetry.lock'
  'go.sum'
  'composer.lock'
  'Pipfile.lock'
  # Generated / build artifacts
  '*.min.js'
  '*.min.css'
  '*.generated.*'
  '*.pb.go'
  '*.pb.ts'
  '*_generated.go'
  '*_gen.go'
  'dist/*'
  'build/*'
  'vendor/*'
  'node_modules/*'
  '*.map'
)

# Fetch full diff, then filter out excluded file sections with awk
DIFF_RAW=$(mktemp)
gh pr diff "$PR_NUMBER" > "$DIFF_RAW" 2>/dev/null \
  || { rm -f "$DIFF_RAW"; die "Failed to fetch diff for PR #$PR_NUMBER."; }

# Convert glob patterns to a pipe-delimited string for awk, turning * into .*
PATTERN_RE=$(printf '%s\n' "${EXCLUDE_PATTERNS[@]}" | sed 's/\./\\./g; s/\*/.*/g' | paste -sd'|' -)

awk -v patterns="$PATTERN_RE" '
  BEGIN { split(patterns, pats, "|"); skip=0 }
  /^diff --git/ {
    skip=0
    for (i in pats) {
      if ($0 ~ pats[i]) { skip=1; break }
    }
  }
  !skip { print }
' "$DIFF_RAW" > "$DIFF_FILE"
rm -f "$DIFF_RAW"

DIFF_LINES=$(wc -l < "$DIFF_FILE" | tr -d ' ')

# --- Output JSON ---

jq -n \
  --argjson number "$PR_NUMBER" \
  --arg title "$PR_TITLE" \
  --arg headRef "$HEAD_REF" \
  --arg baseRef "$BASE_REF" \
  --argjson issueNumber "$ISSUE_NUMBER" \
  --arg issueTitle "$ISSUE_TITLE" \
  --arg issueBody "$ISSUE_BODY" \
  --arg diffFile "$DIFF_FILE" \
  --argjson diffLines "$DIFF_LINES" \
  '{
    pr: {
      number: $number,
      title: $title,
      headRef: $headRef,
      baseRef: $baseRef
    },
    issue: {
      number: $issueNumber,
      title: $issueTitle,
      body: $issueBody
    },
    diff: {
      file: $diffFile,
      lines: $diffLines
    }
  }'
