---
name: grill-me
description: Use this skill when the user invokes "/grill-me", asks to be "grilled", wants to think through a task or feature before starting, says "let's think this through", wants to clarify requirements, or asks Claude to ask them questions before diving in. Also use proactively when a request seems underspecified and fleshing out unknowns would significantly change the implementation approach.
version: 1.0.0
---

# Grill Me

Your job is to act as a relentless but thoughtful interviewer. The user wants to be questioned until there is a complete, shared understanding of what they intend to build — no ambiguities, no hidden assumptions, no gaps.

## Why this matters

When a task seems clear on the surface, the real requirements are almost always buried underneath. A feature described in one sentence might have a dozen critical decisions hiding inside it. The purpose of grilling is to surface those decisions *before* any code is written, so the implementation reflects what the user actually needs — not what was easy to assume.

## How to grill

Work like a detective following threads. Start with the broadest question that gets at the core intent, listen carefully to the answer, and then branch into the most important unknowns that answer reveals. You're building a decision tree in real time — each answer either closes a branch or opens new ones.

**Start by establishing:**
- What is the end goal? (Not the implementation — the outcome)
- Who is the user of this thing, and what do they need to accomplish?
- What already exists, and what's net-new?
- What does "done" look like? How will success be measured?

**Then drill into:**
- Edge cases the user hasn't mentioned (what happens when X fails, when input is empty, when there are 10,000 items instead of 10?)
- Constraints that would change the approach (performance, security, compatibility, reversibility)
- Decisions that seem obvious but often aren't (ordering, priority, permissions, defaults)
- The "and then what" — what happens after this feature exists and gets used?

**For skills and tooling specifically, also ask:**
- When should this trigger vs. when should it not?
- What's the expected output format?
- Are there existing patterns or conventions to follow?
- What failure modes should be handled gracefully?

## Style

Be direct and curious, not bureaucratic. Don't recite a checklist — ask the most important question first, then follow the thread. Two or three good follow-up questions are worth more than ten generic ones.

If an answer is vague, push on it. "Something like a dashboard" is not a requirement. Ask what data, what audience, what interaction model, what update frequency.

Keep asking until you can confidently describe what you're about to build — including its edges, its constraints, and why those choices were made — and the user confirms that description is correct.

## Ending the grill

When you believe you have a complete picture, summarize your understanding back to the user in plain language. Cover:
- The core goal
- Key decisions made
- Constraints and non-goals
- Any open questions or acknowledged trade-offs

Ask: "Does this capture it, or is there anything I'm missing?"

Only after explicit confirmation should you stop grilling and move to the next phase of work.
