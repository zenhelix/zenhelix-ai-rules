---
root: false
targets: ["claudecode"]
description: "Testing requirements: 80% coverage, TDD workflow, test pyramid"
globs: ["**/*"]
---

# Testing Requirements

## Minimum Test Coverage: 80%

All new code must achieve at least 80% line and branch coverage. Coverage is enforced at build time.

## Test Pyramid

1. **Unit Tests** — Individual functions, utilities, pure logic
    - Fast, isolated, no external dependencies
    - Mock external collaborators
    - Majority of test suite

2. **Integration Tests** — API endpoints, database operations, service interactions
    - Test real interactions between components
    - Use embedded databases or TestContainers
    - Verify correct wiring and configuration

3. **E2E Tests** — Critical user flows
    - Test the system as a whole
    - Focus on happy paths and critical error paths
    - Run against a realistic environment

## Test-Driven Development (TDD)

MANDATORY workflow for new features and bug fixes:

1. **RED** — Write a test that describes the expected behavior. Run it. It MUST fail.
2. **GREEN** — Write the minimal implementation to make the test pass. No more.
3. **IMPROVE** — Refactor both code and tests. Remove duplication. Improve naming.
4. Verify coverage is at or above 80%.

## Test Quality Guidelines

- Each test verifies ONE behavior
- Tests are independent and can run in any order
- Use descriptive test names that explain the scenario and expected outcome
- Arrange-Act-Assert (AAA) structure
- No logic in tests (no if/else, loops)
- Test edge cases: nulls, empty collections, boundary values, error paths

## Troubleshooting Test Failures

1. Check test isolation — shared mutable state is the most common cause
2. Verify mocks are set up correctly
3. Fix the implementation, not the test (unless the test is wrong)
4. Run the failing test in isolation to confirm
5. Check for flaky tests caused by timing or ordering
