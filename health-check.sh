#!/usr/bin/env bash
set -euo pipefail

# health-check.sh — Validate structural integrity of every skill in the plugin.
#
# Usage: bash health-check.sh
#
# Checks:
#   - Each skills/*/SKILL.md has valid YAML frontmatter with name and description
#   - .claude-plugin/plugin.json exists and is valid JSON
#   - Any .sh files referenced in SKILL.md files exist and are executable
#
# stdout: per-skill PASS/FAIL report and summary
# exit 0: all checks pass
# exit 1: any check fails

PLUGIN_ROOT="$(cd "$(dirname "$0")" && pwd)"

total=0
passed=0
failed=0
manifest_error=false

fail_skill() {
  local skill_name="$1"
  local reason="$2"
  echo "✗ ${skill_name}: ${reason}"
  failed=$((failed + 1))
}

pass_skill() {
  local skill_name="$1"
  echo "✓ ${skill_name}"
  passed=$((passed + 1))
}

# --- Validate plugin manifest ---

manifest="${PLUGIN_ROOT}/.claude-plugin/plugin.json"
if [[ ! -f "$manifest" ]]; then
  echo "✗ plugin.json: file not found at .claude-plugin/plugin.json"
  manifest_error=true
else
  if ! jq empty "$manifest" 2>/dev/null; then
    echo "✗ plugin.json: invalid JSON"
    manifest_error=true
  fi
fi

# --- Validate each skill ---

for skill_dir in "${PLUGIN_ROOT}"/skills/*/; do
  [[ -d "$skill_dir" ]] || continue
  skill_name="$(basename "$skill_dir")"
  total=$((total + 1))
  skill_file="${skill_dir}SKILL.md"

  if [[ ! -f "$skill_file" ]]; then
    fail_skill "$skill_name" "SKILL.md not found"
    continue
  fi

  # Extract frontmatter (text between first and second ---)
  first_line="$(head -n 1 "$skill_file")"
  if [[ "$first_line" != "---" ]]; then
    fail_skill "$skill_name" "missing YAML frontmatter delimiters"
    continue
  fi

  frontmatter="$(awk 'NR==1 && /^---$/ {found=1; next} found && /^---$/ {exit} found {print}' "$skill_file")"

  if [[ -z "$frontmatter" ]]; then
    fail_skill "$skill_name" "empty or malformed YAML frontmatter"
    continue
  fi

  # Check for name field
  if ! echo "$frontmatter" | grep -q '^name:'; then
    fail_skill "$skill_name" "missing 'name' in frontmatter"
    continue
  fi

  # Check for description field
  if ! echo "$frontmatter" | grep -q '^description:'; then
    fail_skill "$skill_name" "missing 'description' in frontmatter"
    continue
  fi

  # Check script references
  skill_errors=""

  # Match patterns like ${CLAUDE_SKILL_DIR}/script.sh or ${CLAUDE_PLUGIN_ROOT}/skills/name/script.sh
  while IFS= read -r sh_ref; do
    [[ -z "$sh_ref" ]] && continue

    # Resolve the path by replacing variables with actual directories
    resolved="$sh_ref"
    resolved="${resolved//\$\{CLAUDE_SKILL_DIR\}/${skill_dir%/}}"
    resolved="${resolved//\$\{CLAUDE_PLUGIN_ROOT\}/${PLUGIN_ROOT}}"

    if [[ ! -f "$resolved" ]]; then
      skill_errors="referenced script '$(basename "$sh_ref")' not found"
      break
    elif [[ ! -x "$resolved" ]]; then
      skill_errors="referenced script '$(basename "$sh_ref")' is not executable"
      break
    fi
  done < <({ grep -oE '\$\{CLAUDE_SKILL_DIR\}/[^ "]+\.sh|\$\{CLAUDE_PLUGIN_ROOT\}/[^ "]+\.sh' "$skill_file" 2>/dev/null || true; } | sort -u)

  if [[ -n "$skill_errors" ]]; then
    fail_skill "$skill_name" "$skill_errors"
    continue
  fi

  pass_skill "$skill_name"
done

# --- Summary ---

echo ""
echo "${total} skills checked, ${passed} passed, ${failed} failed"

if [[ "$failed" -gt 0 || "$manifest_error" == true ]]; then
  exit 1
fi

exit 0
