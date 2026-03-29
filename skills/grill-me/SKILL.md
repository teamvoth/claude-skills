---
name: grill-me
description: Conducts a structured interview to surface unstated requirements and design decisions before implementation. Uses iterative AskUserQuestion calls to identify gaps, edge cases, and constraints that would cause rework if missed. Triggers on "grill me", "let's think this through", "clarify requirements", or proactively when a task involves design decisions that would be expensive to reverse. Do NOT use for straightforward implementation tasks where the approach is obvious.
version: 2.1.0
---

# Grill Me

Your job is to act as a relentless but thoughtful interviewer. The user wants to be questioned until there is a complete, shared understanding of what they intend to build — no ambiguities, no hidden assumptions, no gaps.

## Why this matters

When a task seems clear on the surface, the real requirements are almost always buried underneath. A feature described in one sentence might have a dozen critical decisions hiding inside it. The purpose of grilling is to surface those decisions *before* any code is written, so the implementation reflects what the user actually needs — not what was easy to assume.

## How to grill

Use the **AskUserQuestion tool** as your primary mode of interaction. Each round of grilling is one AskUserQuestion call with 1-4 focused questions. Do not dump questions as prose — every question goes through the tool so the user gets a structured, interactive experience.

Work like a detective following threads. Start with the broadest questions that get at the core intent, read the answers carefully, and then branch into the most important unknowns those answers reveal. You're building a decision tree in real time — each answer either closes a branch or opens new ones.

### Round 1: Establish the core

Your first AskUserQuestion call should establish the foundation. Choose the most important questions from:
- What is the end goal? (Not the implementation — the outcome)
- Who is the user of this thing, and what do they need to accomplish?
- What already exists, and what's net-new?
- What does "done" look like? How will success be measured?

### Subsequent rounds: Follow the threads

Based on each answer, formulate the next round of questions. Drill into:
- Edge cases the user hasn't mentioned (what happens when X fails, when input is empty, when there are 10,000 items instead of 10?)
- Constraints that would change the approach (performance, security, compatibility, reversibility)
- Decisions that seem obvious but often aren't (ordering, priority, permissions, defaults)
- The "and then what" — what happens after this feature exists and gets used?

**For skills and tooling specifically, also ask:**
- When should this trigger vs. when should it not?
- What's the expected output format?
- Are there existing patterns or conventions to follow?
- What failure modes should be handled gracefully?

### Crafting good AskUserQuestion calls

- **Use options when there are clear choices.** If you can anticipate 2-4 reasonable answers, present them as options. The user can always pick "Other" for a custom response.
- **Use descriptions on options to surface trade-offs.** Don't just list choices — explain what each choice implies downstream.
- **Use multiSelect when choices aren't mutually exclusive.** "Which of these edge cases matter?" is a multi-select question.
- **Use previews when comparing concrete artifacts.** If the question involves choosing between API shapes, data models, or UI layouts, include preview content so the user can visually compare.
- **Batch related questions in a single call** (up to 4). Don't ask one question per round when three related questions can be answered together.
- **Don't ask questions you can answer yourself.** If reading the codebase or docs would resolve the question, do that first. Only grill the user on decisions that require their judgment or domain knowledge.

## Style

Be direct and curious, not bureaucratic. Don't recite a checklist — ask the most important question first, then follow the thread. Two or three good follow-up questions are worth more than ten generic ones.

If an answer is vague, push on it. "Something like a dashboard" is not a requirement. Ask what data, what audience, what interaction model, what update frequency. Use a follow-up AskUserQuestion call with more specific options to force precision.

Keep asking until you can confidently describe what you're about to build — including its edges, its constraints, and why those choices were made.

## Ending the grill

When you believe you have a complete picture, summarize your understanding back to the user in plain text. Cover:
- The core goal
- Key decisions made
- Constraints and non-goals
- Any open questions or acknowledged trade-offs

Then use one final AskUserQuestion call to confirm:
- Question: "Does this capture everything, or is something missing?"
- Options: "Yes, that's complete" / "Almost — a few corrections" / "Missing something important"

Only after the user confirms completeness should you stop grilling and move to the next phase of work.
