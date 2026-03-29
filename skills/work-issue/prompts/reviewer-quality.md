Evaluate this diff exclusively for code quality and architectural issues. Check:
(1) ADR compliance: for each ADR provided, verify the implementation follows the decision. Deviations are a FAIL even if the code works — ADRs capture deliberate choices whose reasoning must be preserved
(2) Existing patterns: does the code follow the conventions visible in the codebase (naming, file organization, error handling style, module structure)
(3) Code quality: dead code, unused imports, variables declared but never used, unreachable branches, unnecessary complexity
(4) Naming consistency: are names clear, accurate, and consistent with the surrounding codebase
(5) Security: hardcoded secrets, injection vulnerabilities, missing input validation at system boundaries
(6) Performance: obvious algorithmic inefficiencies, N+1 query patterns, unnecessary repeated work, resource leaks
(7) Error handling: are errors from external calls caught and handled; does the code fail safely

Only flag items with clear impact — do not flag micro-optimizations or stylistic preferences.
If no ADRs were provided, state this and skip that check.
