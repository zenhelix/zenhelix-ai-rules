---
description: "Analyze local git history to extract coding patterns and generate SKILL.md files"
targets: ["claudecode"]
---

# Skill Create Command

## Purpose

Analyze the local git history to identify recurring coding patterns, conventions,
and workflows, then generate structured SKILL.md files that capture this knowledge.
This is a local alternative to the GitHub App pattern extraction.

## When to Use

- When setting up AI rules for an existing project
- After accumulating significant git history (50+ commits)
- To formalize team conventions into machine-readable skills
- When onboarding new team members or AI assistants
- Periodically to capture evolving project patterns

## Workflow

### Step 1: Analyze Git History

Scan recent git history (default: last 200 commits) for patterns:

```bash
git log --oneline -200
git log --stat -200
git log --diff-filter=A -200  # Added files
git log --diff-filter=M -200  # Modified files
```

Extract signals:

- **Commit conventions**: Message format, types used, scoping patterns
- **File co-changes**: Files that are always modified together
- **Recurring workflows**: Common sequences of file changes
- **Architecture patterns**: Package structure, naming conventions
- **Testing patterns**: Test file placement, naming, frameworks used

### Step 2: Identify Patterns

| Pattern Type      | Signal                         | Example                                     |
|-------------------|--------------------------------|---------------------------------------------|
| Commit Convention | Consistent prefix format       | `feat(auth):`, `fix(api):`                  |
| File Co-change    | Files always changed together  | `Entity + Repository + Migration`           |
| Architecture      | Consistent package structure   | `controller/service/repository` layers      |
| Testing           | Test file naming and placement | `*Test.kt` in `src/test/kotlin/`            |
| Code Style        | Recurring code structures      | Data classes with companion factory methods |
| Dependency        | Common library usage patterns  | Always using Mockk, never Mockito           |

### Step 3: Generate SKILL.md Files

For each identified pattern, create a SKILL.md file:

```markdown
---
name: "<skill-name>"
version: 1
description: "<what this skill captures>"
globs:
  - "<relevant file patterns>"
tags:
  - "<tag>"
---

# <Skill Name>

## Pattern Description
<What the pattern is and why it exists>

## Rules
- <Rule 1>
- <Rule 2>

## Examples

### Correct
<example of correct application>

### Incorrect
<example of what to avoid>

## Detected From
- Commits analyzed: <count>
- Confidence: HIGH/MEDIUM/LOW
- First seen: <date>
- Last seen: <date>
```

### Step 4: Categorize and Place

Organize generated skills by type:

- `skills/conventions/` — Commit messages, naming, style
- `skills/architecture/` — Module structure, layering, patterns
- `skills/testing/` — Test patterns, frameworks, coverage
- `skills/workflow/` — Development workflow patterns

### Step 5: Review and Confirm

Present all generated skills for review:

- Show each skill with confidence level
- Highlight LOW confidence patterns for user judgment
- Allow selective approval (accept some, reject others)
- Write approved skills to the skills directory

## Output Format

```
## Skill Extraction Report

### Git History Analyzed
- Commits scanned: 200
- Date range: 2024-06-01 to 2024-12-15
- Contributors: 4

### Patterns Found: <count>

| # | Skill | Type | Confidence | Commits |
|---|-------|------|------------|---------|
| 1 | conventional-commits | Convention | HIGH | 180/200 |
| 2 | entity-repo-cochange | Co-change | HIGH | 45/50 |
| 3 | mockk-testing | Testing | HIGH | 30/30 |
| 4 | companion-factory | Code Style | MEDIUM | 12/20 |

### Generated Files
1. skills/conventions/conventional-commits.md
2. skills/architecture/entity-repo-cochange.md
3. skills/testing/mockk-testing.md
4. skills/workflow/companion-factory.md

### Approve? [all / 1,2,3 / none]
```

## Arguments

- No arguments — Analyze last 200 commits
- `--depth=<n>` — Number of commits to analyze
- `--since=<date>` — Only analyze commits after date
- `--author=<name>` — Filter by author
- `--dry-run` — Show patterns without generating files

## Rules

- NEVER generate skills with LOW confidence without user approval
- ALWAYS show generated skills before writing files
- Prefer HIGH confidence patterns (>80% consistency in history)
- Do not duplicate patterns already captured in existing skills
- Include provenance data (which commits support the pattern)
- Keep skills focused: one pattern per file
