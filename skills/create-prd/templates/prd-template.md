# PRD: [Feature Name]

## Overview

[One to two paragraphs. What is this feature, why does it exist, and what problem does it solve? Write for someone who has no context — your future self six months from now.]

## Goals

- [What does success look like from a user/product perspective?]
- [Each goal should be outcome-oriented, not implementation-oriented]
- [...]

## Out of Scope

The following are explicitly not part of this feature:

- [...]
- [...]

## User Stories / Functional Requirements

[Describe what the product does from the user's perspective. Use present tense. Stay implementation-agnostic — describe behavior, not mechanism. Each requirement should hold true regardless of what stack or architecture is used.]

**[Logical grouping if needed]**

- The system [does X when Y]
- Users can [accomplish Z]
- [...]

## Quality Attributes

[What non-functional properties matter for this feature, and why? These shape *how* the code is built — not just what it does. Only include attributes that are genuinely relevant; not every feature needs every category. For each attribute, state the constraint and the reasoning behind it.]

[Quality attributes flow downstream: they become quality constraints on issues and calibration context for reviewers. An attribute listed here means "the implementor must reason about this" and "the reviewer must verify this."]

**[Attribute category, e.g. Performance]**

- [Specific constraint with rationale. E.g., "Pipeline stages execute sequentially on a single GPU — each stage must release model resources before the next stage loads. Holding multiple models in VRAM simultaneously will cause OOM."]

**[Attribute category, e.g. Security]**

- [Specific constraint with rationale. E.g., "API keys arrive via environment variables and must never appear in config files, logs, or error messages. The system processes user-provided URLs for article fetching — URL inputs must be validated before use."]

**[Attribute category, e.g. Reliability]**

- [Specific constraint with rationale.]

**[Attribute category, e.g. Modularity]**

- [Specific constraint with rationale. E.g., "Each agent is a separate subcommand with no shared mutable state. Public APIs between modules use types that enforce valid usage at compile time — prefer newtype wrappers and builders over raw strings and booleans."]

[Common categories: Performance, Security, Reliability, Modularity, Observability, Testability, Compatibility. Use what fits — don't force categories that aren't relevant.]

## Acceptance Criteria

[Specific, testable conditions that define "done". These cover functional correctness — the system does what it should. Quality attributes above cover how well it does it.]

[Each criterion should be verifiable by a human tester or by automated test. Written as assertions — either true or false.]

- [ ] [Condition that must be true]
- [ ] [Condition that must be true]
- [ ] [...]

## Open Questions

[Unresolved decisions or known unknowns at time of writing. It's fine to ship a PRD with open questions — capture them so they don't get lost.]

- [Question or decision not yet made]
- [...]
