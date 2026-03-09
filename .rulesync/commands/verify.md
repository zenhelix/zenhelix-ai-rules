---
description: "Run comprehensive verification on current codebase state"
targets: ["claudecode"]
---

# Verify Command

## Purpose

Run a sequential verification pipeline to confirm the codebase is in a healthy
state. Each step must pass before the next one runs. Provides a clear pass/fail
report for every stage.

## When to Use

- Before committing changes
- Before creating a pull request
- After completing a feature or fix
- As a final check in the `/orchestrate` workflow
- When unsure if recent changes broke anything

## Arguments

- `--mode=quick` — Build + tests only (default)
- `--mode=full` — All stages including coverage and lint
- `--mode=pre-commit` — Build + lint + tests
- `--mode=pre-pr` — All stages plus git status check

## Verification Pipeline

### Stage 1: Build

- Run `./gradlew build -x test` (or `mvn compile -DskipTests`)
- Verify compilation succeeds for all modules
- Report any warnings

### Stage 2: Lint (full, pre-commit, pre-pr modes)

- Run detekt for Kotlin: `./gradlew detekt`
- Run SpotBugs for Java: `./gradlew spotbugsMain`
- Run ktlint/spotless if configured
- Report violations grouped by severity

### Stage 3: Tests

- Run full test suite: `./gradlew test`
- Report pass/fail counts
- List any failing test names with brief error descriptions
- Flag flaky tests (tests that fail intermittently)

### Stage 4: Coverage Check (full, pre-pr modes)

- Run JaCoCo: `./gradlew jacocoTestReport`
- Parse coverage report
- Check against 80% threshold for:
    - Line coverage
    - Branch coverage
- List modules or packages below threshold

### Stage 5: Git Status (pre-pr mode)

- Check for uncommitted changes
- Check for untracked files that should be committed
- Verify branch is up to date with remote
- Check for merge conflicts

## Output Format

```
## Verification Report — Mode: <mode>

| Stage | Status | Details |
|-------|--------|---------|
| Build | PASS/FAIL | <summary> |
| Lint | PASS/FAIL/SKIP | <violation count> |
| Tests | PASS/FAIL | <pass>/<total> passed |
| Coverage | PASS/FAIL/SKIP | <percent>% (threshold: 80%) |
| Git Status | PASS/FAIL/SKIP | <summary> |

### Overall: PASS / FAIL

### Failures
- [Stage] <details>
```

## Behavior

- Stops on first FAIL in sequential mode
- Reports all stages even if early ones fail (for visibility)
- Detects available tools automatically (skips lint if detekt not configured)
- Uses Gradle wrapper (`./gradlew`) if present, falls back to system Gradle
- Caches build results where possible for speed

## Example

```
User: /verify --mode=pre-pr
Assistant:
  Stage 1: Build — PASS (12 modules, 0 warnings)
  Stage 2: Lint — PASS (0 violations)
  Stage 3: Tests — PASS (347/347 passed)
  Stage 4: Coverage — PASS (86.2% line, 81.5% branch)
  Stage 5: Git Status — PASS (clean, up to date with origin/main)
  Overall: PASS
```
