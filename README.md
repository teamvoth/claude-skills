# claude-skills

A curated set of Claude Code skills for structured feature development — from idea to merged PR.

## Skills

| Skill | Purpose |
|---|---|
| `/grill-me` | Interview-driven requirements gathering before any work starts |
| `/create-prd` | Generate a Product Requirements Document, create the feature branch |
| `/prd-to-issues` | Break a PRD into sequenced GitHub issues, one per acceptance criterion |
| `/work-issue` | Autonomously implement the next ready issue and open a PR |
| `/pr-review` | Evaluate a task PR against its issue, PRD, and codebase standards — merge if ready |
| `/feature-pr` | Open the final PR from the feature branch to main after all issues are closed |
| `/setup-repo` | Configure GitHub branch protection and repo settings to enforce the workflow |

## Install

Clone this repository to your machine:

```bash
git clone https://github.com/bradvoth/claude-skills.git ~/claude-skills
```

Then open Claude Code, point it at this README, and say:

> "Install the claude-skills plugin on this machine following the README"

Claude will register the plugin by adding the following to `~/.claude/plugins/installed_plugins.json`:

```json
"claude-skills@local": [
  {
    "scope": "user",
    "installPath": "/Users/<you>/claude-skills",
    "version": "local",
    "installedAt": "<current-timestamp>",
    "lastUpdated": "<current-timestamp>"
  }
]
```

And enable it in `~/.claude/settings.json`:

```json
"enabledPlugins": {
  "claude-skills@local": true
}
```

Then restart Claude Code. Run `/reload-plugins` to confirm the skills loaded.

## Auto-Update

The plugin automatically pulls the latest changes from GitHub at the start of every Claude Code session. Updates are live on the next restart after a pull lands.

## Contributing

Submit a PR. Merged changes propagate to everyone on their next Claude Code session start.
