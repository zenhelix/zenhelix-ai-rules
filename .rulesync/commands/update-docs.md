---
description: "Sync documentation with the codebase, generating from source-of-truth files"
targets: ["claudecode"]
---

# Update Docs Command

## Purpose

Automatically synchronize documentation with the current codebase state.
Generates documentation from source-of-truth files like build configurations,
API specs, and Dockerfiles. Flags stale documentation and preserves
manually-written content.

## When to Use

- After changing public APIs or endpoints
- After updating dependencies or build configuration
- After modifying Docker setup or deployment config
- When documentation is flagged as outdated (>90 days since last update)
- As part of the `/orchestrate` workflow before PR creation

## Workflow

### Step 1: Identify Source-of-Truth Files

Scan the project for documentation sources:

- `build.gradle.kts` / `pom.xml` — Project metadata, dependencies, versions
- `openapi.yaml` / `swagger.json` — API endpoint documentation
- `Dockerfile` / `docker-compose.yml` — Deployment and environment docs
- `application.yml` / `application.properties` — Configuration reference
- Source code annotations — `@Api`, `@Operation`, KDoc/Javadoc

### Step 2: Detect Documentation Drift

Compare documentation against source-of-truth:

- API docs mention endpoints that no longer exist
- README references outdated dependency versions
- Configuration docs list properties that have been removed
- Changelog has not been updated for recent changes

### Step 3: Generate Updated Documentation

For each documentation target:

#### README.md

- Update project description from build metadata
- Update dependency versions table
- Update build/run instructions if scripts changed
- Preserve manually-written sections (marked with `<!-- manual -->`)

#### API Documentation

- Regenerate endpoint list from OpenAPI spec or controller annotations
- Update request/response examples
- Flag deprecated endpoints
- Update authentication requirements

#### Configuration Reference

- List all configuration properties with types and defaults
- Mark required vs optional properties
- Group by feature/module

### Step 4: Flag Stale Documentation

- Check git blame dates on all documentation files
- Flag any file not updated in >90 days
- Cross-reference with code changes in the same period
- Report files that likely need manual review

### Step 5: Present Changes

- Show diff of all documentation changes
- Highlight sections that were auto-generated vs preserved
- Wait for user confirmation before writing files

## Output Format

```
## Documentation Update Report

### Sources Analyzed
- build.gradle.kts — version 2.3.1 (was 2.2.0 in docs)
- openapi.yaml — 3 new endpoints, 1 removed
- Dockerfile — base image updated

### Changes Made
| File | Section | Change |
|------|---------|--------|
| README.md | Dependencies | Updated version table |
| API.md | /api/users | Added POST endpoint |
| CONFIG.md | database | New pool-size property |

### Stale Documentation (>90 days)
- DEPLOYMENT.md — last updated 142 days ago, 8 code changes since

### Preserved Manual Content
- README.md: "Contributing" section (unchanged)
- README.md: "Architecture" section (unchanged)
```

## Rules

- NEVER overwrite manually-written documentation sections
- ALWAYS generate from source-of-truth files, not from memory
- Preserve existing formatting and style
- Use project's documentation conventions (if any)
- Flag conflicts between docs and code rather than silently fixing

## Agent

This command invokes the **doc-updater** agent for documentation analysis and generation.
