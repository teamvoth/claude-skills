## What This Accomplishes

[One short paragraph. What user-facing capability does this slice deliver? Write it so Claude can understand the intent without reading the entire PRD.]

## PRD Reference

`docs/PRD/{{feature-name}}.md`

Full context, goals, and constraints for this feature are documented there.

## Acceptance Criteria

[Copy the specific acceptance criteria from the PRD that this issue satisfies. These are the exact conditions that must be true for this issue to be considered complete.]

- [ ] [Criterion]
- [ ] [Criterion]

## Quality Constraints

[Which quality attributes from the PRD apply to this specific issue, and what do they mean concretely for this slice? Not every PRD quality attribute applies to every issue — only include the ones that should shape implementation and review for *this* code.]

[For each relevant attribute, state what it means in the context of this issue. Be specific enough that the implementor knows what to reason about and the reviewer knows what to verify.]

- **[Category]**: [What this means for this issue. E.g., "This module parses untrusted input from external URLs — validate and sanitize before processing. Malformed input must produce a clear error, not a panic."]
- **[Category]**: [E.g., "This is the hot path for stage execution — avoid unnecessary allocations in the per-stage loop. Clone only when ownership transfer is required."]

[If no quality attributes from the PRD apply to this issue, write "None — this is a straightforward functional slice." This is a valid answer; not every slice has quality-sensitive code.]

## Test Scenarios

[For each acceptance criterion above, write at least one concrete test scenario. These are the tests the implementor must write — not suggestions, specifications. Each scenario must be specific enough that two different implementors would write essentially the same test.]

### [Criterion name or short description]

| Scenario | Input / Setup | Action | Expected Result |
|---|---|---|---|
| [Happy path] | [Specific input data or preconditions] | [What the test does] | [Exact expected output or behavior] |
| [Edge case] | [Setup] | [Action] | [Expected result] |
| [Error case] | [Setup that triggers failure] | [Action] | [Expected error behavior] |

[Repeat for each acceptance criterion. Every criterion must have at least one scenario. Error cases and edge cases described in the PRD must appear here — do not leave them for the implementor to invent.]

## Out of Scope

The following are explicitly not part of this issue:

- [What this issue does NOT do — be specific. Prevents Claude from over-implementing.]
- [Functionality covered by other issues in this feature]
- [Anything deferred to a future feature]

## Architectural Decisions

[List any ADRs that govern this issue's implementation. If none apply, write "None." These are binding constraints — the implementor must follow them.]

- `docs/ADR/{{NNNN}}-{{slug}}.md` — [one-line summary of how it affects this issue]

## Technical Notes

[Optional. Relevant files, patterns, or constraints Claude should be aware of. Point to existing code when it provides useful context. Leave blank if the implementation approach is straightforward from the acceptance criteria alone.]

## Dependencies

[List any issues that must be merged before this one can begin, e.g. "Depends on #12". If none, write "None."]

## Definition of Done

Before opening a PR, confirm:

- [ ] All acceptance criteria above are satisfied
- [ ] Every test scenario in the Test Scenarios section has a corresponding automated test
- [ ] All tests pass when run locally against real services (not mocks)
- [ ] Quality constraints above are addressed (not just functional correctness)
- [ ] No functionality outside the scope of this issue is added or modified
- [ ] PR targets the `feature/{{feature-name}}` branch
