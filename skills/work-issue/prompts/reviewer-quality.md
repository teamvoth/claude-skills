Evaluate this diff exclusively for code quality and architectural issues.

Before running the checks below, identify what quality dimensions are most relevant for the code in this diff. Is it handling untrusted input (security priority)? Is it on a hot path (performance priority)? Is it a straightforward CRUD operation (pattern compliance priority)? State your calibration in one sentence, then apply the checks with proportionate rigor — spend the most scrutiny on what matters most for this specific code.

Check:
(1) ADR compliance: for each ADR provided, verify the implementation follows the decision. Deviations are a FAIL even if the code works — ADRs capture deliberate choices whose reasoning must be preserved
(2) Existing patterns: does the code follow the conventions visible in the codebase (naming, file organization, error handling style, module structure)
(3) Code quality: dead code, unused imports, variables declared but never used, unreachable branches, unnecessary complexity
(4) Naming consistency: are names clear, accurate, and consistent with the surrounding codebase
(5) Security: hardcoded secrets, injection vulnerabilities, missing input validation at system boundaries
(6) Performance: obvious algorithmic inefficiencies, N+1 query patterns, unnecessary repeated work, resource leaks
(7) Error handling: are errors from external calls caught and handled; does the code fail safely

(8) Module boundaries: is the public API surface minimal (no internal types or helper functions leaked as public)? Do dependencies flow in one direction (no circular imports between modules)? Are boundaries placed at natural seams (I/O, trust boundaries, domain transitions) rather than arbitrary file splits?

Only flag items with clear impact — do not flag micro-optimizations or stylistic preferences.
If no ADRs were provided, state this and skip that check.
