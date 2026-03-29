Evaluate this diff for test quality and coverage. Check prescribed scenario compliance, independent coverage quality, and end-to-end/integration test sufficiency.

PART A — Test Scenario Compliance:
(1) Find the "Test Scenarios" section in the issue body. It contains scenarios per acceptance criterion, each with Input/Setup, Action, and Expected Result
(2) For every scenario, find the corresponding automated test in the diff. Trace each scenario to a specific test function — name both the scenario and the test
(3) Verify the test actually exercises the described Input/Setup, performs the described Action, and asserts the described Expected Result. A test that only partially covers a scenario is incomplete
(4) Any prescribed test scenario with no corresponding test is a FAIL. Any scenario where the test does not match the prescribed Input/Action/Expected Result is a FAIL
(5) If the issue has no Test Scenarios section, return WARN and note the gap — then fall back to checking that each acceptance criterion has at least one test

PART B — E2E & Integration Test Coverage:
(1) Identify every user-facing behavior and external integration introduced or modified in the diff. For each, determine whether an end-to-end or integration test exercises it through the real system boundary (HTTP endpoint, CLI invocation, message queue, database, file system, external API). A unit test that validates internal logic does not satisfy this — the test must prove the feature works as a user or upstream system would interact with it
(2) Check that e2e/integration tests hit real services and real infrastructure, not mocks or stubs. Tests that mock the database, API client, or service layer at the integration level provide false confidence and are a FAIL
(3) For each acceptance criterion, ask: "If this feature were deployed, would these tests have caught a regression before a user did?" If the answer is no — because the test only checks internal functions, or only checks the happy path, or mocks away the integration point — flag the gap
(4) Look for missing UAT-style scenarios: user workflows that span multiple steps or components (e.g., create → retrieve → update → verify), error recovery paths a user would encounter (invalid input, service unavailable, partial failure), and boundary conditions at system edges (empty responses from external APIs, timeouts, malformed payloads)
(5) Any acceptance criterion with no e2e or integration test exercising it through a real system boundary is a FAIL. Any e2e/integration test that mocks away the integration point it claims to test is a FAIL

PART C — Test Quality (independent of prescribed scenarios):
(1) Read the production code in the diff. Identify all code paths, branches, error handlers, and edge cases. Flag any untested paths
(2) Evaluate test meaningfulness: would the tests catch regressions? Look for tests with no meaningful assertions, tests that assert implementation details rather than behavior, or tests that would pass even if the production code returned hardcoded values
(3) Evaluate assertion quality: do tests verify behavioral correctness (correct output, correct data, correct side effects) or just "no error thrown"? For features that generate or transform data, are there assertions on output quality — format conformance, grounding (outputs traceable to inputs), semantic correctness?
(4) Do the test file structure, naming conventions, and assertion patterns match the existing codebase style

Any acceptance criterion lacking e2e/integration coverage is a FAIL. Any production code path with no test coverage is a WARN. Tests that mock the integration point they claim to exercise are a FAIL. Tests with no meaningful assertions are a FAIL.
