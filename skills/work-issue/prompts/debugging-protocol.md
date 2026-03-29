# Debugging Protocol

When tests fail or reviewers flag issues, follow this 4-phase protocol. Do not skip phases. Do not make multiple changes at once.

## Phase 1: Root Cause Investigation

Read the full error output — stack traces, assertion messages, exit codes. Do not skim.

- Identify the specific assertion or error that failed
- Trace backward from the error to the code that produced it
- Determine whether this is a test bug, a code bug, or a missing dependency
- **Do not change any code yet**

## Phase 2: Pattern Analysis

Before fixing, check for patterns:

- Is this the same root cause as a previous failure in this cycle? If so, the earlier fix was incomplete — don't apply a second patch on top
- Are multiple failures caused by one underlying issue? Group them. One fix may resolve several failures
- Is there similar working code elsewhere in the codebase? Study how it handles the same case

## Phase 3: Hypothesis and Fix

State your hypothesis explicitly: "This fails because [X]. Changing [Y] should fix it because [Z]."

- Make a **single-variable change** to test that hypothesis
- Do not fix multiple things at once — if the fix works, you need to know which change fixed it
- If the fix requires understanding you don't have, read more code before changing anything

## Phase 4: Verify

Run the **full test suite**, not just the failing test. A targeted fix can break unrelated tests.

- If the fix worked and all tests pass: proceed
- If the fix didn't work: return to Phase 1 with the new information (the hypothesis was wrong)
- If the fix introduced new failures: revert and return to Phase 2

## Escalation

After **3 complete cycles** through these phases without resolution, stop. This indicates either:
- An architectural issue that can't be fixed in isolation
- A misunderstanding of the requirements
- A flawed test scenario

Escalate to the user as a blocker. Include in your report:
1. What each cycle attempted and observed
2. Your current hypothesis about the root cause
3. What decision or information you need to proceed
