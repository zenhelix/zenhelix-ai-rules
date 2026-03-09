---
description: "Enforce test-driven development workflow. Scaffold interfaces, generate tests FIRST, then implement minimal code to pass. Ensure 80%+ coverage."
targets: ["claudecode"]
---

# TDD Command

## Purpose

Enforce a strict test-driven development workflow. Tests are always written before
implementation code. The goal is clean, minimal implementations that satisfy well-defined
test cases and achieve at least 80% coverage.

## When to Use

- Implementing any new feature or function
- Fixing bugs (write a test that reproduces the bug first)
- Refactoring existing code (ensure tests exist before changing)
- When coverage for a module is below 80%

## Workflow: RED -> GREEN -> REFACTOR

### Step 1: Scaffold Interfaces (DESIGN)

- Define public interfaces, data classes, and type signatures
- Create empty implementations that compile but throw NotImplementedError
- Establish the contract before any logic is written
- Place interfaces in appropriate packages following project conventions

### Step 2: Write Failing Tests (RED)

- Write test cases BEFORE any implementation
- Cover the following categories in order:
    1. Happy path: expected inputs produce expected outputs
    2. Error cases: invalid inputs, missing data, null values
    3. Edge cases: empty collections, boundary values, concurrent access
    4. Branch coverage: every conditional path exercised
- Use JUnit 5 with descriptive `@DisplayName` annotations
- Use AssertJ or Kotlin test assertions for readable checks
- Run tests and CONFIRM they all FAIL

### Step 3: Implement Minimal Code (GREEN)

- Write the simplest code that makes all tests pass
- Do NOT add logic that no test requires
- Do NOT optimize prematurely
- Run tests and CONFIRM they all PASS

### Step 4: Refactor (IMPROVE)

- Clean up duplication, naming, and structure
- Extract helper functions if any function exceeds 50 lines
- Apply immutable patterns (no mutation of existing objects)
- Run tests again and CONFIRM they still PASS

### Step 5: Verify Coverage

- Run coverage tool (JaCoCo for JVM projects)
- Check that new code has 80%+ line and branch coverage
- If below threshold, return to Step 2 and add missing tests

## Output Format

After each cycle, report:

```
## TDD Cycle Report
- Tests written: <count>
- Tests passing: <count>
- Coverage: <percentage>%
- Status: RED / GREEN / COMPLETE
```

## Rules

- NEVER write implementation before tests
- NEVER skip the RED phase (tests must fail first)
- NEVER modify tests to make them pass (fix implementation instead)
- ALWAYS run tests after each step to verify state
- Keep test files adjacent to source files or in matching test directories

## Integration

- Follows `/plan` for knowing what to implement
- Precedes `/code-review` for quality verification
- Use `/test-coverage` if coverage needs further improvement

## Example

```
User: Implement a UserService.findById method
Assistant: [invokes /tdd]
  1. DESIGN: Creates UserService interface with findById(id: Long): User?
  2. RED: Writes 4 tests (found, not found, invalid id, null handling) — all fail
  3. GREEN: Implements findById with repository call — all pass
  4. IMPROVE: Extracts validation, renames variables — still passing
  5. Coverage: 92% — COMPLETE
```

## Agent

This command invokes the **tdd-guide** agent for workflow enforcement.
