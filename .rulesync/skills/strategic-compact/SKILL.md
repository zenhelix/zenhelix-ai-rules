---
name: strategic-compact
description: "Guide for strategic context compaction in Claude Code sessions — when to compact, what survives, and JVM-specific considerations"
targets: ["claudecode"]
claudecode:
  model: haiku
---

# Strategic Context Compaction

Guide for making informed decisions about when and how to compact context in Claude Code sessions.

## When to Compact

Use this table to decide whether compaction is appropriate at each phase transition:

| Transition                | Compact? | Why                                                                                                          |
|---------------------------|----------|--------------------------------------------------------------------------------------------------------------|
| Research → Planning       | Yes      | Research context is bulky — search results, file reads, and exploration reasoning consume significant tokens |
| Planning → Implementation | Yes      | Plan is persisted in TodoWrite task list and/or files on disk; conversation context is no longer needed      |
| Implementation → Testing  | Maybe    | Keep context if tests reference recently written code; compact if switching to unrelated test suite          |
| Debugging → Next feature  | Yes      | Debug traces, stack traces, and failed hypotheses pollute context with irrelevant reasoning                  |
| Mid-implementation        | No       | Losing file paths, variable names, and in-progress state is costly and leads to re-reading                   |
| After failed approach     | Yes      | Clear dead-end reasoning to free tokens for a fresh approach                                                 |

## What Survives Compaction

Understanding what persists vs. what is lost helps you prepare:

| Persists                      | Lost                                       |
|-------------------------------|--------------------------------------------|
| CLAUDE.md instructions        | Intermediate reasoning and analysis        |
| TodoWrite task list           | File contents previously read              |
| Memory files (MEMORY.md)      | Multi-step conversation context            |
| Git state (commits, branches) | Tool call history                          |
| Files on disk                 | Verbal user preferences (not written down) |
| `.claude/settings.json`       | Agreed-upon decisions (unless recorded)    |

## Pre-Compact Checklist

Before triggering compaction, ensure nothing important is lost:

1. **Commit or stash changes** — any uncommitted work is safe on disk, but you may forget what was in progress
2. **Write session notes** — record current decisions, open questions, and next steps to MEMORY.md
3. **Note current phase** — include in the compact summary message so the resumed session knows where you are
4. **Update TodoWrite** — mark completed items, add any newly discovered tasks
5. **Record verbal preferences** — if the user stated preferences not in CLAUDE.md, write them to MEMORY.md

## JVM-Specific Considerations

JVM projects are particularly context-hungry:

- **Gradle build output** — verbose by default. Summarize build results (pass/fail + error count) before compacting rather than keeping full
  output
- **Stack traces** — a single Spring Boot stack trace can consume 100+ lines. Extract the root cause line and discard the rest
- **Spring context logs** — `DEBUG`-level Spring logs eat tokens rapidly. Only retain log lines directly related to the issue
- **Compilation errors** — Kotlin/Java compiler errors are often repetitive (one missing import causes cascade). Summarize to unique errors
  only
- **Test output** — summarize as `X passed, Y failed` with only the failed test names and assertion messages

## Context Pressure Indicators

Recognize when compaction is needed:

- **Repeated re-reading** — reading the same file multiple times in a session because contents were forgotten
- **Forgetting decisions** — asking about something already discussed and decided
- **Degraded output quality** — responses become less precise, miss previously established context
- **Hallucinating file contents** — confidently stating file contents that don't match reality
- **Circular reasoning** — revisiting approaches already tried and abandoned
- **Slow tool selection** — taking longer to decide which tool to use for familiar operations

## Best Practices

1. **Compact after planning** — once the plan is written to TodoWrite or a file, the planning conversation is expendable
2. **Compact after debugging** — debug sessions generate the most throwaway context
3. **Use `/compact` with a summary message** — provide a brief message describing current state, e.g.:
   ```
   /compact Implementing phase 2 of 4 (repository layer). Auth module complete and tested.
   Next: UserRepository and OrderRepository. See TodoWrite for full plan.
   ```
4. **Never compact mid-edit** — if you're in the middle of modifying a file, finish the edit first
5. **Batch compaction with phase transitions** — align compaction with natural project phases rather than arbitrary points
6. **Prefer explicit state over memory** — write important context to files rather than relying on conversation memory
