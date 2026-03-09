---
description: "Manage eval-driven development workflow"
targets: ["claudecode"]
---

# Eval Command

## Purpose

Define, run, and track evaluations that measure whether the AI assistant
produces correct outputs for specific tasks. Supports both capability evals
(can it do X?) and regression evals (does it still do X correctly?).

## When to Use

- When defining a new capability the assistant should have
- After making changes to rules, skills, or prompts
- To verify that improvements do not regress existing capabilities
- As a quality metric for prompt/rule changes

## Subcommands

### `eval define`

Create a new evaluation:

```
/eval define <name>
```

Prompts for:

- **Description**: What capability is being tested
- **Type**: `capability` (new ability) or `regression` (existing behavior)
- **Input**: The prompt or scenario to test
- **Expected output**: What correct behavior looks like
- **Grading criteria**: How to score (exact match, contains, semantic, manual)
- **Tags**: Categorization labels

Saves eval definition to `.claude/evals/<name>.yaml`:

```yaml
name: "<name>"
type: "capability"
description: "<description>"
input: |
  <the test prompt>
expected: |
  <expected output or behavior>
grading:
  method: "contains"  # exact | contains | semantic | manual
  criteria:
    - "must include error handling"
    - "must use immutable patterns"
tags: ["kotlin", "error-handling"]
```

### `eval check`

Run evaluations:

```
/eval check              # Run all evals
/eval check <name>       # Run a specific eval
/eval check --tag=kotlin # Run evals with specific tag
```

For each eval:

1. Execute the input prompt
2. Capture the output
3. Grade against expected output using the specified method
4. Record result (PASS / FAIL / PARTIAL)

### `eval report`

Show evaluation metrics:

```
/eval report
```

Output:

```
## Eval Report

### Summary
- Total evals: 24
- Passing: 20 (83.3%)
- Failing: 3 (12.5%)
- Partial: 1 (4.2%)

### By Type
- Capability: 15/18 passing (83.3%)
- Regression: 5/6 passing (83.3%)

### By Tag
| Tag | Pass | Fail | Rate |
|-----|------|------|------|
| kotlin | 8/10 | 2 | 80% |
| security | 5/5 | 0 | 100% |
| api | 7/9 | 2 | 78% |

### Failing Evals
1. [FAIL] kotlin-null-safety — Expected null check, got unsafe cast
2. [FAIL] api-pagination — Missing offset parameter
3. [FAIL] error-handling-service — Swallowed exception
```

### `eval list`

List all defined evals:

```
/eval list
/eval list --tag=security
/eval list --type=regression
```

## Workflow Integration

### Capability-Driven Development

1. Define eval for the desired capability
2. Run eval — confirm it FAILS (capability does not exist yet)
3. Implement the capability (update rules, skills, prompts)
4. Run eval — confirm it PASSES
5. Add as regression eval to prevent future breakage

### Regression Prevention

1. Before changing rules or skills, run all regression evals
2. Make changes
3. Re-run regression evals
4. If any regress, fix before proceeding

## Rules

- Eval definitions are stored in version control
- NEVER modify eval expected output to make a failing eval pass
- ALWAYS investigate failing evals — they indicate real problems
- Keep eval inputs realistic (use actual user scenarios)
- Tag evals thoroughly for filtered execution
- Review eval definitions periodically for relevance
