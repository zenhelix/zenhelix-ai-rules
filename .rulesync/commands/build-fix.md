---
description: "Incrementally fix build and type errors with minimal, safe changes"
targets: ["claudecode"]
---

# Build Fix Command

## Purpose

Detect, diagnose, and incrementally fix build errors with minimal changes.
Each fix is verified before moving to the next error, preventing cascading
breakage from overly aggressive changes.

## When to Use

- Build fails after code changes
- Compilation errors in Kotlin or Java files
- Gradle or Maven configuration errors
- Dependency resolution failures
- After merging branches with conflicts

## Workflow

### Step 1: Detect Build System

- Check for `build.gradle.kts` or `build.gradle` (Gradle)
- Check for `pom.xml` (Maven)
- Identify multi-module structure if present
- Determine Kotlin, Java, or mixed project

### Step 2: Run Build and Capture Errors

- Execute build command: `./gradlew build` or `mvn compile`
- Capture full error output
- Parse errors into structured list:
    - File path
    - Line number
    - Error type (syntax, type mismatch, unresolved reference, etc.)
    - Error message

### Step 3: Group and Prioritize

- Group errors by file
- Identify root-cause errors (fix these first, dependent errors may resolve)
- Priority order:
    1. Import / dependency errors (may resolve many downstream errors)
    2. Type errors and unresolved references
    3. Syntax errors
    4. Configuration errors

### Step 4: Fix One at a Time

For each error (starting with highest priority):

1. Read the file and surrounding context
2. Determine the minimal fix
3. Apply the fix
4. Re-run build to verify
5. If new errors appear, assess whether they are related
6. Move to the next error

### Step 5: Verify Clean Build

- Run full build one final time
- Run tests to ensure no regressions
- Report results

## Recovery Strategies

| Error Type           | Strategy                                         |
|----------------------|--------------------------------------------------|
| Unresolved reference | Check imports, add missing dependency            |
| Type mismatch        | Check expected vs actual types, add conversion   |
| Missing override     | Add override or update interface                 |
| Dependency conflict  | Check version alignment, use resolution strategy |
| Gradle script error  | Validate DSL syntax, check plugin versions       |
| Out of memory        | Increase Gradle heap in gradle.properties        |
| Annotation processor | Verify kapt/ksp configuration                    |

## Rules

- NEVER make speculative bulk changes
- Fix ONE error at a time and re-verify
- Prefer minimal changes over rewrites
- Do NOT change test expectations to fix build (fix source code)
- If a fix would change public API, warn the user first
- After 3 failed attempts on the same error, ask the user for guidance

## Output Format

```
## Build Fix Report

### Build System: Gradle (Kotlin DSL)
### Initial Errors: <count>

### Fix Log
1. [file.kt:42] Unresolved reference 'UserDto' — Added import
2. [file.kt:58] Type mismatch — Changed return type to List<User>
3. ...

### Result: BUILD SUCCESSFUL / STILL FAILING (<remaining> errors)
### Tests: PASSED / FAILED (<count> failures)
```

## Agent

This command invokes the **build-error-resolver** agent for diagnosis and fixing.
