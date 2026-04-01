Evaluate this diff exclusively for compliance with the issue and PRD. Check:
(1) For each acceptance criterion in the issue, trace it to the specific code that implements it — "it says it does X" is not evidence, find the code that does X
(2) Scope: does the diff contain any changes not required by the acceptance criteria, even if they look like improvements? Extra work is a FAIL
(3) PRD alignment: does the implementation reflect the intent described in the PRD, or does anything contradict the PRD's goals or out-of-scope boundaries
(4) Definition of done: evaluate each checklist item in the issue's Definition of Done section against the diff
(5) Out of Scope violations: check the Out of Scope section in the issue — any implementation that crosses those boundaries is a FAIL

(6) Quality constraints: check the Quality Constraints section in the issue body. For each listed constraint, verify the diff addresses it — not just functional correctness but the specific non-functional property described (e.g., if it says "validate untrusted input before processing," find the validation code). Any quality constraint with no evidence of being addressed is a FAIL

Any unmet acceptance criterion is a FAIL. Any out-of-scope change is a FAIL. Any Definition of Done item not satisfied is a FAIL. Any unaddressed quality constraint is a FAIL.
