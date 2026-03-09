---
name: project-context
description: "Project context: summarize goals, constraints, dependencies, architecture decisions, conventions"
targets: ["claudecode"]
claudecode:
  model: haiku
  allowed-tools: ["Read", "Grep", "Glob", "Bash"]
---

# Project Context Analysis

## Purpose

Analyze a project to produce a structured summary of its goals, stack, dependencies, architecture, and conventions. Use this skill when
onboarding to a new codebase or when context is needed for decision-making.

## Analysis Steps

### 1. Identify Build System and Configuration

- Read `settings.gradle.kts` — project name, included modules, plugin management
- Read `build.gradle.kts` (root and key modules) — plugins, dependencies, configurations
- Read `gradle/libs.versions.toml` — version catalog for all dependency versions
- Check `gradle.properties` — JVM args, feature flags, build settings

### 2. Determine Technology Stack

- Kotlin or Java version (from version catalog or build script)
- Spring Boot version and enabled starters
- Database: check for JDBC/R2DBC drivers, migration tools (Flyway/Liquibase)
- Messaging: Kafka, RabbitMQ, or other brokers
- Caching: Redis, Caffeine, or other cache providers
- Testing: JUnit 5, Kotest, MockK, Mockito, TestContainers

### 3. Map Project Structure

- List all modules from `settings.gradle.kts`
- Identify module responsibilities from package names and dependencies
- Determine layering: API, service, domain, infrastructure
- Check for shared/common modules

### 4. Extract Key Dependencies

- Read `gradle/libs.versions.toml` for the full dependency list
- Group by category: framework, database, messaging, testing, utilities
- Note version constraints and BOMs

### 5. Review Architecture Decisions

- Check for `CLAUDE.md`, `ARCHITECTURE.md`, or ADR documents
- Look for `.rulesync/` rules that encode decisions
- Examine package structure for architectural patterns (hexagonal, layered, modular)
- Check for multi-module boundaries and dependency rules

### 6. List Conventions

- Code style: check for Detekt, Spotless, Diktat, or EditorConfig
- Git workflow: check for `.github/`, CI configuration
- Testing: coverage requirements, test organization
- API: versioning scheme, response format, error handling

## Output Format

```markdown
## Project: {name}

### Stack
- Language: Kotlin {version} / Java {version}
- Framework: Spring Boot {version}
- Database: {type} with {migration tool}
- Build: Gradle {version} with Kotlin DSL

### Modules
- `:core` — domain model and business logic
- `:api` — REST controllers and DTOs
- `:infrastructure` — database, messaging, external integrations

### Key Dependencies
- {grouped dependency list with versions}

### Architecture
- {pattern}: {description}
- {key decisions from docs or structure}

### Conventions
- {coding style rules}
- {testing requirements}
- {git workflow}
```

## Validation Steps

After producing the summary:

1. Verify module list matches `settings.gradle.kts`
2. Confirm versions match `libs.versions.toml`
3. Cross-check conventions with actual rule files
4. Ensure no assumptions are made without evidence from the codebase
