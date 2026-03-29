# ADR-0001: Use Bash for Plugin Utility Scripts

## Status

Accepted

## Context

The plugin needs utility scripts for tasks like health checking, context collection, and issue discovery. These scripts are invoked by Claude Code skills via `bash "${CLAUDE_SKILL_DIR}/script.sh"`. The question is what language to use for these scripts.

Options considered:
- **Bash**: Zero dependencies, runs everywhere Claude Code runs, consistent with how skills invoke scripts
- **Python**: More expressive for complex logic, but requires a runtime and adds dependency management overhead (we use `uv run --with` for the one Python script that needs HTML parsing)
- **Node.js**: Available in many environments but not guaranteed

## Decision

Use Bash for all plugin utility scripts unless the task requires capabilities that are impractical in Bash (e.g., HTML parsing). In those cases, use Python via `uv run --with <deps>` for dependency isolation.

## Consequences

### Benefits
- Zero additional dependencies for most scripts
- Consistent invocation pattern: `bash "${CLAUDE_SKILL_DIR}/script.sh"`
- Shell commands (`gh`, `git`, `jq`, `curl`) are first-class citizens
- Scripts are transparent — users can read and understand them easily

### Tradeoffs
- Complex string manipulation and data processing is verbose in Bash
- Error handling requires careful `set -euo pipefail` discipline
- No standard testing framework for Bash scripts

## References

- PRD: `docs/PRD/plugin-health-check.md`
