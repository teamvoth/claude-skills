# PRD: Plugin Health Check

## Overview

A CLI script that validates the structural health of the claude-skills plugin. It checks that all skills have valid SKILL.md files with required frontmatter, that referenced scripts exist and are executable, and that the plugin.json manifest is valid. This provides fast feedback when developing or modifying skills.

## Goals

- Catch structural errors before they reach users (missing files, broken references, invalid frontmatter)
- Run quickly enough to use as a pre-commit check
- Provide clear, actionable error messages

## Non-Goals

- Does not validate the semantic quality of skill descriptions or prompts
- Does not execute any scripts — only checks they exist and are executable
- Does not check SKILL.md content beyond frontmatter fields

## Acceptance Criteria

1. A `health-check.sh` script exists at the plugin root that can be run with `bash health-check.sh`
2. The script validates every `skills/*/SKILL.md` file has a `name` field in its YAML frontmatter
3. The script validates every `skills/*/SKILL.md` file has a `description` field in its YAML frontmatter
4. The script validates that `.claude-plugin/plugin.json` exists and is valid JSON
5. The script validates that any `.sh` files referenced in SKILL.md files exist and are executable
6. The script exits 0 if all checks pass, non-zero if any fail
7. The script prints a summary line for each skill checked (PASS/FAIL with reason)

## Functional Requirements

### Input
- No arguments required — operates on the current working directory
- Assumes it is run from the plugin root (where `.claude-plugin/` lives)

### Output
- One line per skill: `✓ <skill-name>` or `✗ <skill-name>: <reason>`
- Final summary: `N skills checked, M passed, K failed`
- Exit code 0 if all passed, 1 if any failed

### Validation Rules
1. **Frontmatter check**: SKILL.md must start with `---`, contain `name:` and `description:` fields, and close with `---`
2. **Plugin manifest**: `.claude-plugin/plugin.json` must exist and parse as valid JSON
3. **Script references**: Any `bash` command in SKILL.md that references a file path relative to `${CLAUDE_SKILL_DIR}` must point to an existing, executable file

## Open Questions

None — all requirements are specified.
