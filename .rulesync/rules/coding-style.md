---
root: false
targets: ["claudecode"]
description: "Universal coding style: immutability, SOLID, file organization, error handling, code quality"
globs: ["**/*"]
---

# Coding Style

## Immutability (CRITICAL)

ALWAYS create new objects, NEVER mutate existing ones:

```
// Pseudocode
WRONG:  modify(original, field, value) → changes original in-place
CORRECT: update(original, field, value) → returns new copy with change
```

Rationale: Immutable data prevents hidden side effects, makes debugging easier, and enables safe concurrency.

## File Organization

MANY SMALL FILES over FEW LARGE FILES:
- High cohesion, low coupling
- 200-400 lines typical, 800 lines maximum
- Extract utilities from large modules
- Organize by feature/domain, not by file type

## Error Handling

ALWAYS handle errors comprehensively:
- Handle errors explicitly at every level
- Provide user-friendly error messages in UI-facing code
- Log detailed error context on the server side
- Never silently swallow errors
- Use typed/structured errors where the language supports it

## Input Validation

ALWAYS validate at system boundaries:
- Validate all user input before processing
- Use schema-based validation where available
- Fail fast with clear error messages
- Never trust external data (API responses, user input, file content)

## SOLID Principles

- **S**ingle Responsibility: each class/module has one reason to change
- **O**pen/Closed: open for extension, closed for modification
- **L**iskov Substitution: subtypes must be substitutable for base types
- **I**nterface Segregation: prefer many specific interfaces over one general
- **D**ependency Inversion: depend on abstractions, not concretions

## Naming Conventions

- Use descriptive, intention-revealing names
- Avoid abbreviations unless universally understood
- Boolean variables/functions: use is/has/can/should prefixes
- Collections: use plural nouns
- Functions: use verb phrases describing the action

## Code Quality Checklist

Before marking work complete:
- [ ] Code is readable and well-named
- [ ] Functions are small (< 50 lines)
- [ ] Files are focused (< 800 lines)
- [ ] No deep nesting (> 4 levels)
- [ ] Proper error handling at every layer
- [ ] No hardcoded values (use constants or config)
- [ ] No mutation (immutable patterns used)
- [ ] No dead code or commented-out blocks
- [ ] Consistent formatting throughout
