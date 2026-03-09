---
description: "Analyze the current session and extract reusable patterns worth saving as skills"
targets: ["claudecode"]
---

# Learn Command

## Purpose

Analyze the work completed in the current session and extract reusable patterns,
error resolutions, debugging techniques, and project conventions that should be
preserved as skill files for future sessions.

## When to Use

- After solving a difficult debugging problem
- After discovering a non-obvious project convention
- After finding a workaround for a tool or framework limitation
- At the end of a productive session
- When a pattern has been used 3+ times in the same session

## Workflow

### Step 1: Analyze Session History

Review the current conversation for:

- **Error resolutions**: Errors encountered and how they were fixed
- **Debugging techniques**: Approaches that led to root cause discovery
- **Workarounds**: Non-obvious solutions to framework/tool limitations
- **Project conventions**: Patterns specific to this codebase
- **Repeated patterns**: Code structures used multiple times

### Step 2: Classify Patterns

| Category   | Description                  | Example                                                      |
|------------|------------------------------|--------------------------------------------------------------|
| ERROR_FIX  | Solution to a specific error | "Gradle daemon OOM: add `-Dorg.gradle.jvmargs=-Xmx2g`"       |
| DEBUGGING  | Technique for finding issues | "Use `--info` flag with Gradle for dependency resolution"    |
| WORKAROUND | Non-obvious solution         | "Mockk requires `@MockKExtension` for constructor injection" |
| CONVENTION | Project-specific pattern     | "All DTOs use `copy()` for immutable updates"                |
| WORKFLOW   | Process improvement          | "Run detekt before tests to catch issues faster"             |

### Step 3: Generate Skill Files

For each extracted pattern, create a structured skill file:

```markdown
---
name: "<pattern-name>"
category: "<category>"
tags: ["<tag1>", "<tag2>"]
---

# <Pattern Name>

## Problem
<What situation triggers this pattern>

## Solution
<Step-by-step solution>

## Context
<When this applies and when it does not>

## Example
<Concrete example from the session>
```

### Step 4: Save Skills

- Write skill files to `~/.claude/skills/learned/`
- Use kebab-case naming: `gradle-oom-fix.md`, `mockk-constructor-injection.md`
- Do not overwrite existing skills — append version suffix if conflict
- Log extraction to session summary

### Step 5: Report

Present all extracted patterns for user review before saving.

## Output Format

```
## Learning Report

### Patterns Extracted: <count>

| # | Name | Category | Confidence |
|---|------|----------|------------|
| 1 | gradle-daemon-oom | ERROR_FIX | HIGH |
| 2 | mockk-constructor-workaround | WORKAROUND | HIGH |
| 3 | dto-copy-convention | CONVENTION | MEDIUM |

### Details

#### 1. gradle-daemon-oom
- Problem: Build fails with OutOfMemoryError
- Solution: Add JVM args to gradle.properties
- Source: Session error at step 3

#### 2. mockk-constructor-workaround
...

### Actions
- Save all? [Y/n]
- Save specific? [1,2,3]
- Skip? [s]
```

## Rules

- NEVER save patterns with low confidence without user confirmation
- NEVER include secrets, credentials, or sensitive data in skill files
- ALWAYS show extracted patterns to user before saving
- Prefer specific, actionable patterns over vague observations
- Include the problem context so the pattern can be matched in future sessions
- One skill per file (high cohesion)
- Tag skills for searchability
