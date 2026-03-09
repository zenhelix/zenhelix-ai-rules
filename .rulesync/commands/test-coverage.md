---
description: "Analyze test coverage, identify gaps, and generate missing tests to reach 80%+ coverage"
targets: ["claudecode"]
---

# Test Coverage Command

## Purpose

Analyze current test coverage, identify under-covered code, and generate
targeted test cases to bring coverage above the 80% threshold. Focuses on
meaningful coverage, not just line count.

## When to Use

- After implementing a feature to verify test completeness
- When coverage reports show modules below 80%
- Before a release to ensure adequate coverage
- When `/verify` reports coverage failure

## Arguments

- No arguments — Analyze entire project
- `<path>` — Analyze a specific module or package
- `--generate` — Automatically generate missing tests
- `--report-only` — Only report gaps, do not generate tests

## Workflow

### Step 1: Detect Test Framework

- Check for JUnit 5 (default for Kotlin/Java projects)
- Check for Kotest, TestNG, or other frameworks
- Identify assertion libraries (AssertJ, Hamcrest, kotlin.test)
- Identify mocking libraries (Mockk, Mockito)

### Step 2: Run Coverage Analysis

- Execute: `./gradlew jacocoTestReport`
- Parse the generated HTML/XML report
- Extract per-file and per-method coverage data
- Calculate line coverage and branch coverage separately

### Step 3: Identify Gaps

Categorize uncovered code:

| Priority | Type                                | Example                           |
|----------|-------------------------------------|-----------------------------------|
| P0       | Public API methods with 0% coverage | Service methods never tested      |
| P1       | Error handling branches             | Catch blocks, validation failures |
| P2       | Conditional branches                | if/else, when expressions         |
| P3       | Utility methods                     | Helpers, mappers, converters      |
| P4       | Edge cases in covered methods       | Null inputs, empty collections    |

### Step 4: Generate Tests

For each gap (in priority order):

1. **Happy path** — Normal expected input and output
2. **Error cases** — Invalid input, missing data, exceptions
3. **Edge cases** — Empty, null, boundary values
4. **Branch coverage** — Exercise each conditional path

Follow project conventions:

- Match existing test file naming (`*Test.kt`, `*Tests.kt`)
- Use `@DisplayName` for readable test names
- Use arrange/act/assert structure
- Mock external dependencies

### Step 5: Verify Improvement

- Re-run coverage analysis
- Compare before and after
- Report improvement per file and overall
- Flag if still below 80% threshold

## Output Format

```
## Coverage Report

### Current Coverage
| Module | Line % | Branch % | Status |
|--------|--------|----------|--------|
| core | 85.2% | 78.4% | PASS/WARN |
| api | 62.1% | 55.3% | FAIL |

### Gaps Identified
1. [P0] UserService.createUser — 0% coverage (no tests exist)
2. [P1] OrderService.processPayment catch block — not exercised
3. [P2] AuthController.login else branch — not covered

### Tests Generated: <count>
### Coverage After: <line%> line / <branch%> branch
### Delta: +<improvement>%
```

## Rules

- Generate tests that test BEHAVIOR, not implementation details
- Do not generate trivial getter/setter tests
- Use mocks for external services, databases, and I/O
- Each test method tests ONE thing
- Test names describe the scenario: `should return 404 when user not found`
- Never lower the coverage threshold to pass
