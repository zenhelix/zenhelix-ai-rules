---
description: "Run the quality pipeline on demand for a file or project scope"
targets: ["claudecode"]
---

# Quality Gate Command

## Purpose

Run a multi-stage quality pipeline on a specific file, directory, or the
entire project. Optionally auto-fix issues. Acts as a configurable gate
that code must pass before proceeding.

## When to Use

- To check quality of a specific file after editing
- Before committing changes to a particular module
- As a targeted alternative to full `/verify`
- When you want auto-fix capabilities (formatting, import sorting)

## Arguments

- No arguments — Run on all changed files (git diff)
- `<path>` — Run on a specific file or directory
- `--fix` — Auto-fix issues where possible (formatting, imports)
- `--strict` — Treat warnings as errors
- `--stage=<name>` — Run only a specific stage (format, lint, compile, test)

## Pipeline Stages

### Stage 1: Format

Tools (in priority order):

- **Spotless** — `./gradlew spotlessCheck` (or `spotlessApply` with --fix)
- **ktlint** — `./gradlew ktlintCheck` (or `ktlintFormat` with --fix)
- **google-java-format** — For Java files

Checks:

- Consistent indentation (spaces vs tabs)
- Import ordering and grouping
- Trailing whitespace and newlines
- Line length limits
- Brace style

### Stage 2: Lint

Tools:

- **detekt** — Kotlin static analysis
- **SpotBugs** — Java bug pattern detection
- **Checkstyle** — Java style checking (if configured)

Checks:

- Code complexity (cyclomatic, cognitive)
- Unused declarations
- Naming conventions
- Error-prone patterns
- Magic numbers and strings

### Stage 3: Type Check (Compile)

- Run `./gradlew compileKotlin compileJava` for targeted modules
- Report type errors, unresolved references, missing overrides
- Faster than full build when checking specific modules

### Stage 4: Tests

- Run tests relevant to changed files
- Use Gradle's `--tests` filter when targeting specific classes
- Report pass/fail with failure details
- Calculate coverage for affected files

## Output Format

```
## Quality Gate Report

### Scope: <file/directory/project>
### Mode: <normal/fix/strict>

| Stage | Status | Issues | Fixed |
|-------|--------|--------|-------|
| Format | PASS/FAIL | 3 | 3 (--fix) |
| Lint | PASS/FAIL | 2 | 0 |
| Compile | PASS/FAIL | 0 | — |
| Tests | PASS/FAIL | 1 failure | — |

### Issues
1. [LINT] UserService.kt:42 — Function too complex (cyclomatic: 12, max: 10)
2. [LINT] OrderMapper.kt:18 — Magic number: 100
3. [TEST] UserServiceTest.shouldCreateUser — Expected 201 but got 400

### Verdict: PASS / FAIL
```

## Behavior with --fix

When `--fix` is specified:

1. Run formatter and apply fixes automatically
2. Run linter — report but do not auto-fix (lint fixes may change behavior)
3. After formatting, re-run compile and tests to verify fixes are safe
4. Show git diff of all auto-applied changes

## Behavior with --strict

- All warnings become errors
- Zero tolerance: any issue fails the gate
- Useful for critical paths (auth, payment, security modules)

## Rules

- Format fixes are always safe to auto-apply
- Lint fixes require manual review (do not auto-apply)
- If compile fails, skip test stage (no point running tests on broken code)
- Report issues with file path and line number for easy navigation
- When scoped to a file, only run relevant tests (not full suite)
