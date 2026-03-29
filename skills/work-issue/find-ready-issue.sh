#!/usr/bin/env bash
set -euo pipefail

# find-ready-issue.sh — Find the next ready GitHub issue to work on.
# Checks dependency resolution and returns the lowest-numbered open issue
# where all dependencies are closed.
#
# Usage: find-ready-issue.sh [LABEL]
#   LABEL: optional GitHub label to filter issues
#
# stdout: JSON with issue data and dependency audit trail
# stderr: error messages
# exit 0: found a ready issue
# exit 1: no ready issues or error

die() {
  echo "Error: $1" >&2
  exit 1
}

# --- Parse args ---

LABEL="${1:-}"

# --- Fetch open issues ---

GH_ARGS=(issue list --state open --json number,title,body,labels --limit 100)
if [[ -n "$LABEL" ]]; then
  GH_ARGS+=(--label "$LABEL")
fi

ISSUES_JSON=$(gh "${GH_ARGS[@]}" 2>/dev/null) \
  || die "Failed to list GitHub issues."

ISSUE_COUNT=$(echo "$ISSUES_JSON" | jq 'length')
[[ "$ISSUE_COUNT" -gt 0 ]] || {
  if [[ -n "$LABEL" ]]; then
    die "No open issues found with label '$LABEL'."
  else
    die "No open issues found."
  fi
}

# Sort by issue number ascending
ISSUES_JSON=$(echo "$ISSUES_JSON" | jq 'sort_by(.number)')

# --- Dependency resolution ---

# Cache issue states to avoid redundant API calls
declare -A STATE_CACHE

check_state() {
  local num=$1
  if [[ -z "${STATE_CACHE[$num]+x}" ]]; then
    STATE_CACHE[$num]=$(gh issue view "$num" --json state --jq '.state' 2>/dev/null || echo "UNKNOWN")
  fi
  echo "${STATE_CACHE[$num]}"
}

SELECTED_INDEX=""
CHECKED_JSON="[]"

for i in $(seq 0 $((ISSUE_COUNT - 1))); do
  ISSUE_NUM=$(echo "$ISSUES_JSON" | jq -r ".[$i].number")
  ISSUE_BODY=$(echo "$ISSUES_JSON" | jq -r ".[$i].body")

  # Extract Dependencies section (between ## Dependencies and next ## or EOF)
  DEP_SECTION=$(echo "$ISSUE_BODY" | awk '/^## Dependencies/{found=1; next} /^## /{if(found) exit} found{print}')

  # Extract all #N references from the Dependencies section
  DEP_NUMBERS=$(echo "$DEP_SECTION" | grep -oE '#[0-9]+' | grep -oE '[0-9]+' | sort -un || true)

  # Filter out self-references
  DEP_NUMBERS=$(echo "$DEP_NUMBERS" | grep -v "^${ISSUE_NUM}$" || true)

  DEPS_JSON="[]"
  ALL_RESOLVED=true

  for dep_num in $DEP_NUMBERS; do
    [[ -n "$dep_num" ]] || continue
    DEP_STATE=$(check_state "$dep_num")
    DEPS_JSON=$(echo "$DEPS_JSON" | jq --argjson num "$dep_num" --arg state "$DEP_STATE" \
      '. + [{"number": $num, "state": $state}]')
    if [[ "$DEP_STATE" != "CLOSED" ]]; then
      ALL_RESOLVED=false
    fi
  done

  IS_READY=$ALL_RESOLVED
  CHECKED_JSON=$(echo "$CHECKED_JSON" | jq \
    --argjson issue "$ISSUE_NUM" \
    --argjson deps "$DEPS_JSON" \
    --argjson ready "$IS_READY" \
    '. + [{"issue": $issue, "deps": $deps, "ready": $ready}]')

  if [[ "$ALL_RESOLVED" == true && -z "$SELECTED_INDEX" ]]; then
    SELECTED_INDEX=$i
    # Don't break — continue checking remaining issues for the audit trail
    # Actually, we can break to save API calls. The audit trail for unchecked
    # issues is less valuable than speed.
    break
  fi
done

# --- No ready issue found ---

if [[ -z "$SELECTED_INDEX" ]]; then
  echo "No issues are ready to work." >&2
  echo "" >&2
  echo "Blocked:" >&2
  echo "$CHECKED_JSON" | jq -r '.[] | select(.ready == false) |
    "  #\(.issue) — waiting on " +
    ([.deps[] | select(.state != "CLOSED") | "#\(.number) (\(.state))"] | join(", "))' >&2
  exit 1
fi

# --- Output the selected issue ---

SELECTED_ISSUE=$(echo "$ISSUES_JSON" | jq ".[$SELECTED_INDEX]")
SELECTED_NUM=$(echo "$SELECTED_ISSUE" | jq -r '.number')
SELECTED_TITLE=$(echo "$SELECTED_ISSUE" | jq -r '.title')
SELECTED_BODY=$(echo "$SELECTED_ISSUE" | jq -r '.body')
SELECTED_LABELS=$(echo "$SELECTED_ISSUE" | jq '[.labels[].name]')

jq -n \
  --argjson number "$SELECTED_NUM" \
  --arg title "$SELECTED_TITLE" \
  --arg body "$SELECTED_BODY" \
  --argjson labels "$SELECTED_LABELS" \
  --argjson checked "$CHECKED_JSON" \
  --argjson selected "$SELECTED_NUM" \
  '{
    issue: {
      number: $number,
      title: $title,
      body: $body,
      labels: $labels
    },
    dependencies: {
      checked: $checked,
      selected: $selected
    }
  }'
