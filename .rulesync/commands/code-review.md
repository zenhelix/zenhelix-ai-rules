---
description: "Comprehensive security and quality review of uncommitted changes"
targets: ["claudecode"]
---

# Code Review Command

## Purpose

Perform a thorough review of all uncommitted changes, checking for security
vulnerabilities, code quality issues, and adherence to project conventions.
Generates a severity-based report and blocks on CRITICAL or HIGH findings.

## When to Use

- After writing or modifying code, before committing
- As part of the `/orchestrate` workflow
- When unsure about code quality of recent changes
- Before creating a pull request

## Review Dimensions

### 1. Security Review

- **Credentials**: Hardcoded API keys, passwords, tokens, connection strings
- **Injection**: SQL injection, command injection, XSS vectors
- **Authentication**: Missing auth checks, broken access control
- **Secrets in logs**: Sensitive data written to log output
- **Dependencies**: Known CVEs in added or updated dependencies
- **Error leakage**: Stack traces or internal details exposed to users

### 2. Code Quality Review

- **Function size**: Flag functions exceeding 50 lines
- **File size**: Flag files exceeding 800 lines
- **Nesting depth**: Flag nesting deeper than 4 levels
- **Error handling**: Missing catch blocks, swallowed exceptions
- **Naming**: Unclear or misleading variable/function names
- **Duplication**: Repeated logic that should be extracted
- **Magic values**: Hardcoded numbers or strings without constants

### 3. Kotlin/Java Patterns

- **Null safety**: Missing null checks, unsafe casts, platform types
- **Immutability**: Mutable state where immutable would suffice (val vs var, copy())
- **Data classes**: Missing equals/hashCode, mutable properties in data classes
- **Coroutines**: Missing structured concurrency, unhandled exceptions
- **Collections**: Using mutable collections when immutable would work

### 4. Spring Patterns (if applicable)

- **@Transactional**: Missing or misplaced transaction boundaries
- **Validation**: Missing @Valid, unchecked request bodies
- **Exception handling**: Missing @ControllerAdvice, raw exception responses
- **Injection**: Field injection instead of constructor injection
- **Configuration**: Secrets in application.yml instead of environment variables

## Severity Levels

| Severity | Action                 | Examples                                      |
|----------|------------------------|-----------------------------------------------|
| CRITICAL | MUST fix before commit | Hardcoded secrets, SQL injection, auth bypass |
| HIGH     | MUST fix before commit | Missing error handling, unsafe null access    |
| MEDIUM   | SHOULD fix, may defer  | Function too long, unclear naming             |
| LOW      | Nice to fix            | Minor style issues, optional improvements     |
| INFO     | Informational          | Suggestions, alternative approaches           |

## Output Format

```
## Code Review Report

### Summary
- Files reviewed: <count>
- Findings: <count by severity>
- Verdict: PASS / BLOCKED (if CRITICAL or HIGH exist)

### CRITICAL
- [FILE:LINE] <description> — <fix suggestion>

### HIGH
- [FILE:LINE] <description> — <fix suggestion>

### MEDIUM
- [FILE:LINE] <description>

### LOW / INFO
- [FILE:LINE] <description>
```

## Behavior

- Reviews ONLY changed files (staged + unstaged in git diff)
- Groups findings by file for easy navigation
- If CRITICAL or HIGH findings exist, the review verdict is BLOCKED
- Suggests specific fixes, not just descriptions of problems

## Agent

This command invokes the **code-reviewer** and **security-reviewer** agents in parallel.
