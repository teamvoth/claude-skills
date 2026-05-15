# claude-skills

A curated set of Claude Code skills for structured feature development — from idea to merged PR.

## Skills

| Skill | Purpose |
|---|---|
| `/grill-me` | Interview-driven requirements gathering before any work starts |
| `/grill-with-docs` | Like `/grill-me`, grounded in the project's CONTEXT.md and codebase; persists refined glossary and ADRs |
| `/ubiquitous-language` | Bootstrap, audit, reconcile, or split the project's domain glossary (CONTEXT.md) outside of feature work |
| `/create-prd` | Generate a Product Requirements Document, create the feature branch |
| `/prd-to-issues` | Break a PRD into sequenced GitHub issues, one per acceptance criterion |
| `/work-issue` | Autonomously implement the next ready issue and open a PR |
| `/pr-review` | Evaluate a task PR against its issue, PRD, and codebase standards — merge if ready |
| `/feature-pr` | Open the final PR from the feature branch to main after all issues are closed |
| `/setup-repo` | Configure GitHub branch protection and repo settings to enforce the workflow |

## Install

Install from the Claude Code plugin marketplace:

```
/install-plugin bradvoth/claude-skills
```

Then restart Claude Code to activate the skills.

## Auto-Update

Plugin updates are delivered through the marketplace. Updates take effect on your next Claude Code session.

## Contributing

Submit a PR to [bradvoth/claude-skills](https://github.com/bradvoth/claude-skills). Merged changes are published to the marketplace.
