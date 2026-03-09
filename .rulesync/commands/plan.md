---
description: "Restate requirements, assess risks, and create step-by-step implementation plan. WAIT for user CONFIRM before touching any code."
targets: ["claudecode"]
---

# Plan Command

## Purpose

Create a structured implementation plan before writing any code. This command ensures
requirements are fully understood, risks are identified, and a phased approach is agreed
upon before any changes are made to the codebase.

## When to Use

- Before implementing any feature or significant change
- When requirements are ambiguous or complex
- Before large refactoring efforts
- When multiple modules or files will be affected

## Workflow

### Step 1: Restate Requirements

- Summarize the user's request in your own words
- List explicit requirements and implicit constraints
- Identify acceptance criteria
- Ask clarifying questions if anything is ambiguous

### Step 2: Assess Risks

- Identify files and modules that will be affected
- Flag potential breaking changes
- Note dependency conflicts or version issues
- Evaluate impact on existing tests
- Check for security implications

### Step 3: Create Phased Plan

- Break work into independent phases where possible
- For each phase, specify:
    - Files to create or modify
    - Dependencies on other phases
    - Estimated complexity (low / medium / high)
    - Testing approach
- Order phases by dependency graph
- Identify phases that can run in parallel

### Step 4: Present and Wait

- Output the full plan in a structured format
- Highlight any risks or trade-offs
- WAIT for the user to type CONFIRM or provide feedback
- Do NOT proceed to implementation until explicit confirmation

## Output Format

```
## Requirements Summary
<restated requirements>

## Risk Assessment
| Risk | Severity | Mitigation |
|------|----------|------------|

## Implementation Plan
### Phase 1: <name>
- Files: ...
- Depends on: none
- Complexity: low/medium/high
- Tests: ...

### Phase 2: <name>
...

## Parallel Execution Opportunities
<which phases can run simultaneously>
```

## Integration with Other Commands

After the plan is confirmed:

- Use `/tdd` for each phase to enforce test-first development
- Use `/code-review` after each phase to catch issues early
- Use `/verify` before marking the plan complete

## Example Usage

```
User: Add pagination to the user listing API
Assistant: [invokes /plan]
  1. Restates: "Add offset/limit pagination to GET /api/users endpoint"
  2. Risks: breaking change for existing clients, need migration
  3. Plan: Phase 1 (DTO), Phase 2 (Repository), Phase 3 (Controller), Phase 4 (Tests)
  4. Waits for CONFIRM
```

## Agent

This command invokes the **planner** agent for structured planning.
Use extended thinking for complex plans requiring deep analysis.
