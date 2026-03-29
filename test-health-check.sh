#!/usr/bin/env bash
set -euo pipefail

# test-health-check.sh — Automated tests for health-check.sh
#
# Usage: bash test-health-check.sh
#
# Creates temporary skill directories for failure cases, runs health-check.sh,
# validates output and exit codes, then cleans up.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HEALTH_CHECK="${SCRIPT_DIR}/health-check.sh"

tests_run=0
tests_passed=0
tests_failed=0

# Temporary directories to clean up
CLEANUP_DIRS=()

cleanup() {
  for dir in "${CLEANUP_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
      rm -rf "$dir"
    fi
  done
  # Restore plugin.json if it was backed up
  if [[ -f "${SCRIPT_DIR}/.claude-plugin/plugin.json.bak" ]]; then
    mv "${SCRIPT_DIR}/.claude-plugin/plugin.json.bak" "${SCRIPT_DIR}/.claude-plugin/plugin.json"
  fi
}
trap cleanup EXIT

create_temp_skill() {
  local name="$1"
  local content="$2"
  local dir="${SCRIPT_DIR}/skills/${name}"
  mkdir -p "$dir"
  printf '%s\n' "$content" > "${dir}/SKILL.md"
  CLEANUP_DIRS+=("$dir")
}

assert_output_contains() {
  local description="$1"
  local expected="$2"
  local actual="$3"

  if echo "$actual" | grep -qF "$expected"; then
    return 0
  else
    echo "  ASSERTION FAILED: expected output to contain: ${expected}"
    echo "  Actual output:"
    echo "$actual" | sed 's/^/    /'
    return 1
  fi
}

assert_exit_code() {
  local description="$1"
  local expected="$2"
  local actual="$3"

  if [[ "$actual" -eq "$expected" ]]; then
    return 0
  else
    echo "  ASSERTION FAILED: expected exit code ${expected}, got ${actual}"
    return 1
  fi
}

run_test() {
  local name="$1"
  shift
  tests_run=$((tests_run + 1))
  echo "TEST: ${name}"
  if "$@"; then
    echo "  PASS"
    tests_passed=$((tests_passed + 1))
  else
    echo "  FAIL"
    tests_failed=$((tests_failed + 1))
  fi
}

# ============================================================
# Frontmatter validation tests
# ============================================================

test_valid_skill_passes() {
  local output exit_code
  output="$(bash "$HEALTH_CHECK" 2>&1)" && exit_code=0 || exit_code=$?
  assert_output_contains "pr-review passes" "✓ pr-review" "$output"
}

test_missing_name_fails() {
  create_temp_skill "test-bad" "---
description: A test skill
---
# Test"

  local output exit_code
  output="$(bash "$HEALTH_CHECK" 2>&1)" && exit_code=0 || exit_code=$?

  local result=0
  assert_exit_code "exit code 1" 1 "$exit_code" || result=1
  assert_output_contains "missing name" "✗ test-bad: missing 'name'" "$output" || result=1

  rm -rf "${SCRIPT_DIR}/skills/test-bad"
  return $result
}

test_missing_description_fails() {
  create_temp_skill "test-bad2" "---
name: test-bad2
---
# Test"

  local output exit_code
  output="$(bash "$HEALTH_CHECK" 2>&1)" && exit_code=0 || exit_code=$?

  local result=0
  assert_exit_code "exit code 1" 1 "$exit_code" || result=1
  assert_output_contains "missing description" "✗ test-bad2: missing 'description'" "$output" || result=1

  rm -rf "${SCRIPT_DIR}/skills/test-bad2"
  return $result
}

test_no_frontmatter_fails() {
  create_temp_skill "test-bad3" "# No frontmatter here
Just some markdown content."

  local output exit_code
  output="$(bash "$HEALTH_CHECK" 2>&1)" && exit_code=0 || exit_code=$?

  local result=0
  assert_exit_code "exit code 1" 1 "$exit_code" || result=1
  assert_output_contains "frontmatter error" "✗ test-bad3" "$output" || result=1
  # Verify the error message mentions frontmatter
  if ! echo "$output" | grep -q "test-bad3.*frontmatter"; then
    echo "  ASSERTION FAILED: expected output to mention frontmatter for test-bad3"
    result=1
  fi

  rm -rf "${SCRIPT_DIR}/skills/test-bad3"
  return $result
}

# ============================================================
# Plugin manifest validation tests
# ============================================================

test_valid_manifest_passes() {
  local output exit_code
  output="$(bash "$HEALTH_CHECK" 2>&1)" && exit_code=0 || exit_code=$?
  # No manifest errors should appear
  if echo "$output" | grep -q "plugin.json"; then
    echo "  ASSERTION FAILED: expected no plugin.json errors in output"
    echo "  Output: $output"
    return 1
  fi
  assert_exit_code "exit code 0" 0 "$exit_code"
}

test_invalid_json_fails() {
  # Back up the real plugin.json
  cp "${SCRIPT_DIR}/.claude-plugin/plugin.json" "${SCRIPT_DIR}/.claude-plugin/plugin.json.bak"
  # Corrupt it
  echo "{ invalid json }" > "${SCRIPT_DIR}/.claude-plugin/plugin.json"

  local output exit_code
  output="$(bash "$HEALTH_CHECK" 2>&1)" && exit_code=0 || exit_code=$?

  # Restore immediately
  mv "${SCRIPT_DIR}/.claude-plugin/plugin.json.bak" "${SCRIPT_DIR}/.claude-plugin/plugin.json"

  local result=0
  assert_exit_code "exit code 1" 1 "$exit_code" || result=1
  assert_output_contains "invalid JSON" "✗ plugin.json: invalid JSON" "$output" || result=1
  return $result
}

# ============================================================
# Script reference validation tests
# ============================================================

test_existing_executable_script_passes() {
  local output exit_code
  output="$(bash "$HEALTH_CHECK" 2>&1)" && exit_code=0 || exit_code=$?
  # work-issue references find-ready-issue.sh which exists and is executable
  assert_output_contains "work-issue passes" "✓ work-issue" "$output"
}

test_non_executable_script_fails() {
  local skill_dir="${SCRIPT_DIR}/skills/test-noexec"
  mkdir -p "$skill_dir"
  CLEANUP_DIRS+=("$skill_dir")

  cat > "${skill_dir}/SKILL.md" << 'SKILLEOF'
---
name: test-noexec
description: A test skill with non-executable script
allowed-tools: Bash(bash "${CLAUDE_SKILL_DIR}/test.sh")
---
# Test

```bash
bash "${CLAUDE_SKILL_DIR}/test.sh"
```
SKILLEOF

  # Create the script and ensure it is not executable
  echo '#!/usr/bin/env bash' > "${skill_dir}/test.sh"
  chmod -x "${skill_dir}/test.sh"

  local output exit_code
  output="$(bash "$HEALTH_CHECK" 2>&1)" && exit_code=0 || exit_code=$?

  local result=0
  assert_exit_code "exit code 1" 1 "$exit_code" || result=1
  assert_output_contains "non-executable" "✗ test-noexec" "$output" || result=1
  if ! echo "$output" | grep -q "test-noexec.*not executable"; then
    echo "  ASSERTION FAILED: expected output to mention 'not executable' for test-noexec"
    result=1
  fi

  rm -rf "$skill_dir"
  return $result
}

test_missing_referenced_script_fails() {
  local skill_dir="${SCRIPT_DIR}/skills/test-missing"
  mkdir -p "$skill_dir"
  CLEANUP_DIRS+=("$skill_dir")

  cat > "${skill_dir}/SKILL.md" << 'SKILLEOF'
---
name: test-missing
description: A test skill referencing a missing script
allowed-tools: Bash(bash "${CLAUDE_SKILL_DIR}/nonexistent.sh")
---
# Test

```bash
bash "${CLAUDE_SKILL_DIR}/nonexistent.sh"
```
SKILLEOF

  local output exit_code
  output="$(bash "$HEALTH_CHECK" 2>&1)" && exit_code=0 || exit_code=$?

  local result=0
  assert_exit_code "exit code 1" 1 "$exit_code" || result=1
  assert_output_contains "missing script" "✗ test-missing" "$output" || result=1
  if ! echo "$output" | grep -q "test-missing.*not found"; then
    echo "  ASSERTION FAILED: expected output to mention 'not found' for test-missing"
    result=1
  fi

  rm -rf "$skill_dir"
  return $result
}

# ============================================================
# Summary output tests
# ============================================================

test_summary_counts_correct() {
  local output exit_code
  output="$(bash "$HEALTH_CHECK" 2>&1)" && exit_code=0 || exit_code=$?

  # Count actual skill directories
  local skill_count=0
  for d in "${SCRIPT_DIR}"/skills/*/; do
    [[ -d "$d" ]] && skill_count=$((skill_count + 1))
  done

  local result=0
  assert_output_contains "summary line" "${skill_count} skills checked, ${skill_count} passed, 0 failed" "$output" || result=1
  assert_exit_code "exit code 0" 0 "$exit_code" || result=1
  return $result
}

test_mixed_results_summary() {
  create_temp_skill "test-bad-summary" "---
description: No name field
---
# Test"

  local output exit_code
  output="$(bash "$HEALTH_CHECK" 2>&1)" && exit_code=0 || exit_code=$?

  # Count skill directories (includes the temp one)
  local skill_count=0
  for d in "${SCRIPT_DIR}"/skills/*/; do
    [[ -d "$d" ]] && skill_count=$((skill_count + 1))
  done
  local expected_passed=$((skill_count - 1))

  local result=0
  assert_output_contains "mixed summary" "${skill_count} skills checked, ${expected_passed} passed, 1 failed" "$output" || result=1
  assert_exit_code "exit code 1" 1 "$exit_code" || result=1

  rm -rf "${SCRIPT_DIR}/skills/test-bad-summary"
  return $result
}

# ============================================================
# Run all tests
# ============================================================

echo "Running health-check.sh tests..."
echo ""

run_test "Valid skill passes (pr-review)" test_valid_skill_passes
run_test "Missing name fails" test_missing_name_fails
run_test "Missing description fails" test_missing_description_fails
run_test "No frontmatter fails" test_no_frontmatter_fails
run_test "Valid manifest passes" test_valid_manifest_passes
run_test "Invalid JSON manifest fails" test_invalid_json_fails
run_test "Existing executable script passes (work-issue)" test_existing_executable_script_passes
run_test "Non-executable script fails" test_non_executable_script_fails
run_test "Missing referenced script fails" test_missing_referenced_script_fails
run_test "Summary counts correct" test_summary_counts_correct
run_test "Mixed results summary" test_mixed_results_summary

echo ""
echo "========================================="
echo "${tests_run} tests run, ${tests_passed} passed, ${tests_failed} failed"
echo "========================================="

if [[ "$tests_failed" -gt 0 ]]; then
  exit 1
fi

exit 0
