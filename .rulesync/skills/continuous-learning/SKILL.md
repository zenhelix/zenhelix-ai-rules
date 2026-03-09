---
name: continuous-learning
description: "Instinct-based learning system — extract patterns from sessions, store as instincts, reinforce through usage, evolve into skills"
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Continuous Learning System

Instinct-based learning system for extracting, storing, and reinforcing patterns observed during Claude Code sessions. Implemented entirely
in bash (no Python dependencies).

## Concept

The learning loop:

1. **Observe** — notice a repeated pattern during a session
2. **Extract** — formalize as an instinct with trigger, action, and evidence
3. **Store** — persist as a markdown file with structured frontmatter
4. **Reinforce** — increment usage count when the pattern is applied
5. **Evolve** — promote high-confidence instincts into full skills or rules

## Instinct Model

Each instinct is a markdown file with YAML frontmatter:

```yaml
---
id: prefer-functional-style
trigger: "when writing new functions"
confidence: 0.7
domain: code-style
scope: project
last-used: 2026-03-09
usage-count: 5
---
# Prefer Functional Style

## Action
Use functional patterns (higher-order functions, extension functions, sequence pipelines)
over imperative class hierarchies when the logic is stateless transformation.

## Evidence
- Observed 5 instances of functional pattern preference in user feedback
- User corrected class-based approach to functional approach on 2026-03-05
- Kotlin codebase uses `map`/`filter`/`fold` extensively
```

## Instinct Properties

Every instinct must be:

- **Atomic** — one trigger, one action. If an instinct has multiple triggers or actions, split it
- **Confidence-weighted** — scored 0.3 to 0.9 based on evidence strength
- **Domain-tagged** — categorized by area (code-style, testing, architecture, security, tooling, build)
- **Evidence-backed** — includes concrete observations that justify the instinct
- **Scope-aware** — either project-specific or globally applicable

## Confidence Scoring

| Score | Meaning      | Behavior                                                                                |
|-------|--------------|-----------------------------------------------------------------------------------------|
| 0.3   | Tentative    | Suggested only when directly relevant, prefixed with "Based on previous observation..." |
| 0.5   | Moderate     | Applied when relevant, mentioned as a recommendation                                    |
| 0.7   | Strong       | Auto-approved in relevant contexts, applied without explicit mention                    |
| 0.9   | Near-certain | Core behavior, always applied, candidate for promotion to rule/skill                    |

## Confidence Evolution

### Increases

- **Repeated observation** — same pattern confirmed across sessions (+0.1 per confirmation, cap at 0.9)
- **Explicit user approval** — user confirms the pattern is correct (+0.2)
- **Successful application** — instinct applied and no correction followed (+0.05)

### Decreases

- **User correction** — user explicitly overrides or corrects the pattern (-0.2)
- **Context mismatch** — instinct applied in wrong context, user redirects (-0.1)
- **Contradictory evidence** — new observation contradicts the instinct (-0.15)

### Decay

- **30+ days without use** — mark as STALE, reduce confidence by 0.1
- **60+ days without use** — archive to `.claude/instincts/archived/`
- **User can reset** — explicitly revive an archived instinct

## Scope Decision Guide

| Pattern Type          | Scope   | Examples                                                        |
|-----------------------|---------|-----------------------------------------------------------------|
| Framework conventions | project | "Use Spring WebFlux in this project", "JPA fetch joins for N+1" |
| File structure        | project | "Tests in src/test/kotlin", "Migrations in db/migration"        |
| Naming conventions    | project | "Controllers suffixed with Controller", "DTOs in .dto package"  |
| Security practices    | global  | "Validate all input", "Parameterize SQL queries"                |
| Tool workflow         | global  | "Grep before Edit", "Read before Write"                         |
| Error handling        | global  | "Never swallow exceptions", "Log context with errors"           |
| Code style            | project | "Prefer sealed class over enum for state", "Use Result type"    |

## Bash Implementation

Scripts stored in `.claude/scripts/` — no external dependencies beyond bash and standard unix tools.

### record-instinct.sh

Create or update an instinct file:

```bash
#!/usr/bin/env bash
set -euo pipefail

ID="$1"
TRIGGER="$2"
ACTION="$3"
DOMAIN="${4:-general}"
SCOPE="${5:-project}"
EVIDENCE="$6"

INSTINCT_DIR="$HOME/.claude/instincts/$SCOPE"
INSTINCT_FILE="$INSTINCT_DIR/$ID.md"

mkdir -p "$INSTINCT_DIR"

if [[ -f "$INSTINCT_FILE" ]]; then
  # Update: increment usage-count, append evidence
  CURRENT_COUNT=$(grep "^usage-count:" "$INSTINCT_FILE" | awk '{print $2}')
  NEW_COUNT=$((CURRENT_COUNT + 1))
  sed -i.bak "s/^usage-count: .*/usage-count: $NEW_COUNT/" "$INSTINCT_FILE" && rm -f "$INSTINCT_FILE.bak"
  sed -i.bak "s/^last-used: .*/last-used: $(date +%Y-%m-%d)/" "$INSTINCT_FILE" && rm -f "$INSTINCT_FILE.bak"
  echo "- $EVIDENCE" >> "$INSTINCT_FILE"
  echo "Updated instinct: $ID (usage-count: $NEW_COUNT)"
else
  # Create new instinct
  cat > "$INSTINCT_FILE" << EOF
---
id: $ID
trigger: "$TRIGGER"
confidence: 0.3
domain: $DOMAIN
scope: $SCOPE
last-used: $(date +%Y-%m-%d)
usage-count: 1
---
# ${ID//-/ }

## Action
$ACTION

## Evidence
- $EVIDENCE
EOF
  echo "Created instinct: $ID (confidence: 0.3)"
fi
```

### search-instincts.sh

Grep-based search across all instincts:

```bash
#!/usr/bin/env bash
set -euo pipefail

QUERY="$1"
SCOPE="${2:-all}"

INSTINCT_BASE="$HOME/.claude/instincts"

if [[ "$SCOPE" == "all" ]]; then
  SEARCH_DIRS=("$INSTINCT_BASE/project" "$INSTINCT_BASE/global")
else
  SEARCH_DIRS=("$INSTINCT_BASE/$SCOPE")
fi

for dir in "${SEARCH_DIRS[@]}"; do
  [[ -d "$dir" ]] || continue
  grep -rl "$QUERY" "$dir"/*.md 2>/dev/null | while read -r file; do
    ID=$(grep "^id:" "$file" | awk '{print $2}')
    CONF=$(grep "^confidence:" "$file" | awk '{print $2}')
    DOMAIN=$(grep "^domain:" "$file" | awk '{print $2}')
    echo "[$CONF] $ID ($DOMAIN) — $file"
  done
done | sort -t'[' -k2 -rn
```

### reinforce-instinct.sh

Increment usage and optionally boost confidence:

```bash
#!/usr/bin/env bash
set -euo pipefail

ID="$1"
BOOST="${2:-0.05}"

INSTINCT_BASE="$HOME/.claude/instincts"
INSTINCT_FILE=$(find "$INSTINCT_BASE" -name "$ID.md" 2>/dev/null | head -1)

if [[ -z "$INSTINCT_FILE" ]]; then
  echo "Instinct not found: $ID"
  exit 1
fi

# Update usage count
CURRENT_COUNT=$(grep "^usage-count:" "$INSTINCT_FILE" | awk '{print $2}')
NEW_COUNT=$((CURRENT_COUNT + 1))
sed -i.bak "s/^usage-count: .*/usage-count: $NEW_COUNT/" "$INSTINCT_FILE" && rm -f "$INSTINCT_FILE.bak"
sed -i.bak "s/^last-used: .*/last-used: $(date +%Y-%m-%d)/" "$INSTINCT_FILE" && rm -f "$INSTINCT_FILE.bak"

# Boost confidence (cap at 0.9)
CURRENT_CONF=$(grep "^confidence:" "$INSTINCT_FILE" | awk '{print $2}')
NEW_CONF=$(awk "BEGIN {c = $CURRENT_CONF + $BOOST; print (c > 0.9 ? 0.9 : c)}")
sed -i.bak "s/^confidence: .*/confidence: $NEW_CONF/" "$INSTINCT_FILE" && rm -f "$INSTINCT_FILE.bak"

echo "Reinforced: $ID (usage: $NEW_COUNT, confidence: $CURRENT_CONF -> $NEW_CONF)"
```

### list-instincts.sh

List instincts sorted by confidence:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCOPE="${1:-all}"
DOMAIN="${2:-}"

INSTINCT_BASE="$HOME/.claude/instincts"

if [[ "$SCOPE" == "all" ]]; then
  SEARCH_DIRS=("$INSTINCT_BASE/project" "$INSTINCT_BASE/global")
else
  SEARCH_DIRS=("$INSTINCT_BASE/$SCOPE")
fi

for dir in "${SEARCH_DIRS[@]}"; do
  [[ -d "$dir" ]] || continue
  for file in "$dir"/*.md; do
    [[ -f "$file" ]] || continue
    ID=$(grep "^id:" "$file" | awk '{print $2}')
    CONF=$(grep "^confidence:" "$file" | awk '{print $2}')
    FILE_DOMAIN=$(grep "^domain:" "$file" | awk '{print $2}')
    SCOPE_TAG=$(grep "^scope:" "$file" | awk '{print $2}')
    COUNT=$(grep "^usage-count:" "$file" | awk '{print $2}')
    LAST=$(grep "^last-used:" "$file" | awk '{print $2}')

    # Filter by domain if specified
    if [[ -n "$DOMAIN" && "$FILE_DOMAIN" != "$DOMAIN" ]]; then
      continue
    fi

    echo "$CONF|$ID|$FILE_DOMAIN|$SCOPE_TAG|$COUNT|$LAST"
  done
done | sort -t'|' -k1 -rn | column -t -s'|' -N "CONF,ID,DOMAIN,SCOPE,USES,LAST_USED"
```

## Directory Structure

```
~/.claude/instincts/
├── project/                  # Project-scoped instincts
│   ├── prefer-functional.md
│   ├── use-spring-webflux.md
│   └── jpa-fetch-joins.md
├── global/                   # Cross-project instincts
│   ├── validate-input.md
│   ├── grep-before-edit.md
│   └── parameterize-sql.md
└── archived/                 # Decayed instincts (60+ days unused)
    └── old-pattern.md

~/.claude/scripts/
├── record-instinct.sh
├── search-instincts.sh
├── reinforce-instinct.sh
└── list-instincts.sh
```

## Lifecycle

```
NEW (0.3)
  │ Reinforced 3x
  ▼
MODERATE (0.5)
  │ Reinforced 7x more
  ▼
STRONG (0.7)
  │ Reinforced 10x more, consistent application
  ▼
NEAR-CERTAIN (0.9)
  │ Candidate for promotion
  ▼
PROMOTED → Becomes a rule (.rulesync/rules/) or skill (.rulesync/skills/)
```

Promotion criteria:

- Confidence >= 0.9
- Usage count >= 20
- No contradictions in last 10 uses
- Applicable beyond a single project (for global instincts)

## Integration

### With /learn Command

The `/learn` command triggers instinct extraction at session end:

1. Review session for repeated patterns
2. Identify new instincts or reinforce existing ones
3. Call `record-instinct.sh` or `reinforce-instinct.sh`
4. Report changes to the user

### With session-summary Hook

The stop hook outputs a git diff summary. After reviewing it, the `/learn` command can:

1. Scan session for applied instincts
2. Reinforce each used instinct
3. Flag stale instincts (30+ days)
4. Suggest archiving unused instincts

## JVM-Specific Instinct Examples

### Gradle Build Optimization

```yaml
id: gradle-parallel-build
trigger: "when running Gradle builds"
confidence: 0.7
domain: build
scope: project
```

Action: Always use `--parallel` and `--build-cache` flags. Configure in `gradle.properties`.

### Spring Configuration Patterns

```yaml
id: spring-config-properties
trigger: "when adding Spring configuration"
confidence: 0.5
domain: architecture
scope: project
```

Action: Use `@ConfigurationProperties` with `@ConstructorBinding` instead of `@Value` for type-safe configuration.

### Kotlin Idioms

```yaml
id: kotlin-sealed-class-state
trigger: "when modeling states or results"
confidence: 0.7
domain: code-style
scope: global
```

Action: Use sealed classes/interfaces for state modeling instead of enums when states carry different data.

### JPA Gotchas

```yaml
id: jpa-lazy-loading-outside-tx
trigger: "when accessing lazy-loaded JPA associations"
confidence: 0.9
domain: architecture
scope: global
```

Action: Always access lazy associations within a transaction boundary. Use `@Transactional(readOnly = true)` for read operations. Prefer
fetch joins in queries over lazy loading for known access patterns.

### MockK Patterns

```yaml
id: mockk-relaxed-sparingly
trigger: "when creating MockK mocks"
confidence: 0.5
domain: testing
scope: global
```

Action: Avoid `relaxed = true` by default. Explicitly define `every { }` blocks for expected interactions. Use `relaxed` only for
dependencies with many unused methods in the specific test.
