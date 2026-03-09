---
description: "Review a pull request"
targets: ["claudecode"]
---

# Review PR Command

## Purpose

Perform a comprehensive review of a pull request, analyzing code quality,
test coverage, documentation, and security across all commits in the PR.

## When to Use

- When asked to review a specific PR by number or URL
- When reviewing the PR associated with the current branch
- Before approving or merging a pull request

## Arguments

- `<pr-number>` — Review a specific PR by number (e.g., `/review-pr 42`)
- No argument — Review the PR associated with the current branch

## Workflow

### Step 1: Gather PR Context

- Fetch PR metadata using `gh pr view <number>`
- Get the full diff using `gh pr diff <number>`
- List all commits in the PR
- Identify the base branch and compare branch
- Read PR description and any linked issues

### Step 2: Parallel Review Tracks

Launch parallel review agents for independent analysis:

#### Track A: Code Quality

- Function and file size limits
- Naming clarity and consistency
- Error handling completeness
- Immutability adherence
- Nesting depth and complexity
- Code duplication

#### Track B: Test Coverage

- New code has corresponding tests
- Test quality (not just existence)
- Edge cases and error paths covered
- No test anti-patterns (sleeping, flaky assertions)
- Coverage delta (does it improve or regress?)

#### Track C: Documentation

- Public API changes documented
- Breaking changes noted in PR description
- Inline comments for complex logic
- README or changelog updates if needed

#### Track D: Security

- No secrets or credentials in diff
- Input validation on new endpoints
- SQL/command injection vectors
- Auth and authorization checks
- Error messages do not leak internals

### Step 3: Consolidate Findings

- Merge results from all tracks
- Deduplicate overlapping findings
- Assign severity to each finding
- Draft review summary

## Output Format

```
## PR Review: #<number> — <title>

### Overview
- Author: <author>
- Commits: <count>
- Files changed: <count>
- Lines: +<added> / -<removed>

### Code Quality
- <findings>

### Test Coverage
- <findings>

### Documentation
- <findings>

### Security
- <findings>

### Verdict
APPROVE / REQUEST_CHANGES / COMMENT

### Suggested Actions
1. <action item>
2. <action item>
```

## Behavior

- Always reviews ALL commits, not just the latest
- Uses `gh` CLI for all GitHub interactions
- Does not approve or request changes automatically — presents findings for user decision
- Flags breaking changes prominently
- Checks CI status and reports any failures

## Example

```
User: /review-pr 123
Assistant:
  1. Fetches PR #123 metadata and diff
  2. Launches 4 parallel review tracks
  3. Consolidates: 2 MEDIUM code quality, 1 HIGH missing test, 0 security
  4. Verdict: REQUEST_CHANGES — missing test for error path
```
