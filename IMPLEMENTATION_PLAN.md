# Implementation Plan: Full Repository Restructure

## Overview

Complete rewrite of the rulesync rules repository. Reorganize from ad-hoc structure to systematic "general → specific" categorization
aligned with the actual development workflow: documentation, database, backend (Kotlin/Java/Spring), testing, Gradle.

## Principles

- **General to specific**: universal rules → language-specific rules → technology-specific skills
- **Flat structure with prefix naming**: rulesync doesn't support subdirectories, so `{domain}[-{subdomain}].md`
- **Target**: only `claudecode`
- **Reuse existing good content**: rename and adapt, don't rewrite what works

---

## Phase 1: Cleanup

Delete all existing content in `.rulesync/` and regenerate from scratch.

**Files to delete:**

- `.rulesync/rules/*` (18 files)
- `.rulesync/skills/*/SKILL.md` (14 directories)
- `.rulesync/subagents/*` (10 files)
- `.rulesync/commands/*` (18 files)
- `.rulesync/hooks.json`
- `.rulesync/mcp.json`

**Keep unchanged:**

- `.rulesync/.aiignore`
- `rulesync.jsonc` (will be updated)
- `RULESYNC_REFERENCE.md`

---

## Phase 2: Infrastructure

### 2.1 Update `rulesync.jsonc`

```jsonc
{
  "$schema": "https://raw.githubusercontent.com/dyoshikawa/rulesync/refs/heads/main/config-schema.json",
  "targets": ["claudecode"],
  "features": ["rules", "hooks", "ignore", "mcp", "commands", "subagents", "skills"],
  "baseDirs": ["."],
  "delete": true,
  "verbose": false,
  "silent": false,
  "global": false,
  "simulateCommands": false,
  "simulateSubagents": false,
  "simulateSkills": false
}
```

### 2.2 Create `.rulesync/hooks.json`

```json
{
  "version": 1,
  "hooks": {
    "postToolUse": [
      { "matcher": "Write|Edit", "command": ".rulesync/hooks/format-check.sh" }
    ],
    "stop": [
      { "command": ".rulesync/hooks/session-summary.sh" }
    ]
  }
}
```

### 2.3 Create hook scripts in `.rulesync/hooks/`

**`.rulesync/hooks/format-check.sh`**

- Detects available formatters in the project (spotless, ktlint, google-java-format, editorconfig)
- Runs the appropriate formatter on the changed file
- If no formatter found, exits silently (no error)
- Must be idempotent and fast

**`.rulesync/hooks/session-summary.sh`**

- Runs `git diff --stat` to show what changed during the session
- Shows count of modified/added/deleted files
- Brief and non-blocking

### 2.4 Update `.rulesync/mcp.json`

```json
{
  "mcpServers": {
    "serena": {
      "description": "Code analysis and semantic search MCP server",
      "type": "stdio",
      "command": "uvx",
      "args": ["--from", "git+https://github.com/oraios/serena", "serena", "start-mcp-server", "--context", "ide-assistant", "--enable-web-dashboard", "false", "--project", "."],
      "env": {}
    },
    "context7": {
      "description": "Library documentation search server",
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"],
      "env": {}
    },
    "postgres": {
      "description": "PostgreSQL schema analysis and query execution (read-only recommended)",
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres", "${POSTGRES_URL}"],
      "env": {}
    }
  }
}
```

---

## Phase 3: Rules (`.rulesync/rules/`)

16 files. Principle: general → language-specific.

### General (globs: `**/*`)

| # | File                       | Source                   | Action                                                                               |
|---|----------------------------|--------------------------|--------------------------------------------------------------------------------------|
| 1 | `overview.md` (root: true) | existing overview.md     | Adapt: update description, add workflow summary                                      |
| 2 | `coding-style.md`          | existing coding-style.md | Keep: universal immutability, SOLID, clean code                                      |
| 3 | `security.md`              | existing security.md     | Keep: OWASP, secrets, validation, response protocol                                  |
| 4 | `testing.md`               | existing testing.md      | Keep: TDD, coverage 80%, test pyramid                                                |
| 5 | `patterns.md`              | existing patterns.md     | Keep: repository, service layer, API envelope                                        |
| 6 | `git-workflow.md`          | existing git-workflow.md | Keep: conventional commits, PR workflow                                              |
| 7 | `documentation.md`         | NEW                      | Rules for documentation: AsciiDoc/Markdown choice, Mermaid diagrams, continuous docs |
| 8 | `gradle.md`                | NEW                      | Gradle Kotlin DSL, multi-module, version catalogs, convention plugins                |

### Kotlin-specific (globs: `*.kt, *.kts`)

| #  | File                     | Source                          | Action               |
|----|--------------------------|---------------------------------|----------------------|
| 9  | `coding-style-kotlin.md` | existing kotlin-coding-style.md | Rename, keep content |
| 10 | `security-kotlin.md`     | existing kotlin-security.md     | Rename, keep content |
| 11 | `testing-kotlin.md`      | existing kotlin-testing.md      | Rename, keep content |
| 12 | `patterns-kotlin.md`     | existing kotlin-patterns.md     | Rename, keep content |

### Java-specific (globs: `*.java`)

| #  | File                   | Source                        | Action               |
|----|------------------------|-------------------------------|----------------------|
| 13 | `coding-style-java.md` | existing java-coding-style.md | Rename, keep content |
| 14 | `security-java.md`     | existing java-security.md     | Rename, keep content |
| 15 | `testing-java.md`      | existing java-testing.md      | Rename, keep content |
| 16 | `patterns-java.md`     | existing java-patterns.md     | Rename, keep content |

**Deleted rules (not carried over):**

- `performance.md` — Claude operational guidance, not dev rules → move useful bits to overview
- `hooks.md` — Claude operational guidance → not needed as rule
- `agents.md` — Claude operational guidance → not needed as rule
- `development-workflow.md` — merged into overview and commands

---

## Phase 4: Skills (`.rulesync/skills/`)

25 skills organized by domain. Each is a directory with `SKILL.md`.

### Spring skills (10)

| #  | Skill                 | Source                                            | Action                                                                      |
|----|-----------------------|---------------------------------------------------|-----------------------------------------------------------------------------|
| 1  | `spring-core/`        | NEW                                               | DI, configuration, profiles, properties, actuator, auto-configuration       |
| 2  | `spring-web/`         | existing springboot-patterns (partial)            | Extract MVC part: controllers, exception handlers, validation, interceptors |
| 3  | `spring-webflux/`     | NEW                                               | Reactive stack: WebClient, Router functions, Mono/Flux patterns             |
| 4  | `spring-data-jpa/`    | existing jpa-patterns                             | Rename/adapt: repositories, specifications, projections, auditing           |
| 5  | `spring-data-r2dbc/`  | NEW                                               | Reactive repositories, DatabaseClient, R2DBC patterns                       |
| 6  | `spring-security/`    | existing springboot-security                      | Rename: JWT, OAuth2, RBAC, method security, CORS                            |
| 7  | `spring-batch/`       | NEW                                               | Job/Step design, chunk processing, readers/writers/processors               |
| 8  | `spring-cloud/`       | NEW                                               | Config Server, Gateway, Circuit breaker, Service discovery                  |
| 9  | `spring-integration/` | NEW                                               | Message channels, adapters, transformers, flows                             |
| 10 | `spring-test/`        | existing springboot-tdd + springboot-verification | Merge: @SpringBootTest, slices, TestContainers, MockMvc, MockBean           |

### Database skills (5)

| #  | Skill            | Source                                 | Action                                                                  |
|----|------------------|----------------------------------------|-------------------------------------------------------------------------|
| 11 | `postgresql/`    | existing postgres-patterns             | Adapt: types, indexes, EXPLAIN, RLS, partitioning, read-only analysis   |
| 12 | `jooq/`          | NEW                                    | Codegen, typesafe queries, Kotlin DSL, Java DSL, transactions, with JPA |
| 13 | `flyway/`        | existing database-migrations (partial) | Extract Flyway part, expand                                             |
| 14 | `liquibase/`     | existing database-migrations (partial) | Extract Liquibase part, expand                                          |
| 15 | `jpa-hibernate/` | existing jpa-patterns (partial)        | Entity mapping, caching, performance tuning, N+1                        |

### General skills (10)

| #  | Skill                     | Source                    | Action                                                             |
|----|---------------------------|---------------------------|--------------------------------------------------------------------|
| 16 | `api-design/`             | existing api-design       | Rewrite: replace TS/Python/Go examples with Kotlin/Java Spring     |
| 17 | `documentation-asciidoc/` | NEW                       | AsciiDoc syntax, structure, cross-references, includes, callouts   |
| 18 | `documentation-mermaid/`  | NEW                       | Sequence, class, ER, flowchart, C4 diagrams                        |
| 19 | `gradle-plugins/`         | NEW                       | Convention plugins, published plugins, testing, composite builds   |
| 20 | `gradle-config/`          | NEW                       | Multi-module, dependency management, version catalogs, build cache |
| 21 | `tdd-workflow/`           | existing tdd-workflow     | Keep: TDD methodology, mock patterns, coverage                     |
| 22 | `coding-standards/`       | existing coding-standards | Keep: detailed quality guide for Kotlin/Java                       |
| 23 | `backend-patterns/`       | existing backend-patterns | Keep: architecture patterns, caching, error handling               |
| 24 | `security-review/`        | existing security-review  | Rewrite: remove TS/Solana, focus on Spring Security/JVM            |
| 25 | `project-context/`        | existing project-context  | Keep: project summary skill                                        |

**Deleted skills (not carried over):**

- `java-coding-standards/` — merged with `coding-standards/` (avoid duplication)

---

## Phase 5: Subagents (`.rulesync/subagents/`)

9 subagents.

| # | Subagent               | model  | Source   | Action                                                           |
|---|------------------------|--------|----------|------------------------------------------------------------------|
| 1 | `planner`              | opus   | existing | Adapt: remove TS examples, add Kotlin/Java/Spring context        |
| 2 | `architect`            | opus   | existing | Keep: architecture principles are universal                      |
| 3 | `code-reviewer`        | sonnet | existing | Rewrite: remove React/Next.js, add Kotlin/Java/Spring checks     |
| 4 | `security-reviewer`    | sonnet | existing | Rewrite: remove npm/eslint, add OWASP/Spring Security/JVM checks |
| 5 | `tdd-guide`            | sonnet | existing | Keep: TDD methodology is universal                               |
| 6 | `build-error-resolver` | sonnet | existing | Keep: already Kotlin/Java/Gradle focused                         |
| 7 | `database-reviewer`    | sonnet | existing | Keep: already PostgreSQL focused                                 |
| 8 | `doc-updater`          | haiku  | existing | Keep: already JVM focused                                        |
| 9 | `refactor-cleaner`     | sonnet | existing | Keep: already detekt/SpotBugs focused                            |

**Deleted subagents:**

- `e2e-runner` — replaced by `spring-test` skill + `tdd-guide` subagent

---

## Phase 6: Commands (`.rulesync/commands/`)

16 commands.

| #  | Command           | Source   | Action |
|----|-------------------|----------|--------|
| 1  | `plan`            | existing | Keep   |
| 2  | `tdd`             | existing | Keep   |
| 3  | `code-review`     | existing | Keep   |
| 4  | `review-pr`       | existing | Keep   |
| 5  | `build-fix`       | existing | Keep   |
| 6  | `verify`          | existing | Keep   |
| 7  | `test-coverage`   | existing | Keep   |
| 8  | `refactor-clean`  | existing | Keep   |
| 9  | `update-docs`     | existing | Keep   |
| 10 | `update-codemaps` | existing | Keep   |
| 11 | `orchestrate`     | existing | Keep   |
| 12 | `checkpoint`      | existing | Keep   |
| 13 | `quality-gate`    | existing | Keep   |
| 14 | `learn`           | existing | Keep   |
| 15 | `eval`            | existing | Keep   |
| 16 | `skill-create`    | existing | Keep   |

**Deleted commands:**

- `e2e` — Playwright, frontend-only
- `sessions` — Claude tooling, not dev workflow

---

## Phase 7: Implementation Order

Phases are executed in order. Within each phase, independent work is parallelized.

```
Phase 1: Cleanup (delete old files)
    ↓
Phase 2: Infrastructure (rulesync.jsonc, hooks.json, hook scripts, mcp.json)
    ↓
Phase 3-6 IN PARALLEL:
    ├── Agent Group A: Rules (16 files)
    ├── Agent Group B: Spring skills (10 SKILL.md)
    ├── Agent Group C: Database + API skills (6 SKILL.md)
    ├── Agent Group D: General + Gradle + Docs skills (9 SKILL.md)
    ├── Agent Group E: Subagents (9 files)
    └── Agent Group F: Commands (16 files)
    ↓
Phase 7: Quality review
    ↓
Phase 8: Update MEMORY.md
```

---

## File Count Summary

| Category     | Count                                    |
|--------------|------------------------------------------|
| Rules        | 16                                       |
| Skills       | 25                                       |
| Subagents    | 9                                        |
| Commands     | 16                                       |
| Hook scripts | 2                                        |
| Config files | 3 (rulesync.jsonc, hooks.json, mcp.json) |
| **Total**    | **71**                                   |
