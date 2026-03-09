---
name: liquibase
description: "Liquibase: changeset format, YAML/XML, rollback, contexts, labels, Spring Boot integration"
targets: ["claudecode"]
claudecode:
  model: haiku
---

# Liquibase Reference

## Changeset Format

### YAML (Preferred)

```yaml
# db/changelog/db.changelog-master.yaml
databaseChangeLog:
  - includeAll:
      path: db/changelog/changes/
  # Or include specific files:
  - include:
      file: db/changelog/changes/001-create-users.yaml
  - include:
      file: db/changelog/changes/002-create-orders.yaml
```

```yaml
# db/changelog/changes/001-create-users.yaml
databaseChangeLog:
  - changeSet:
      id: 001-create-users-table
      author: team
      changes:
        - createTable:
            tableName: users
            columns:
              - column:
                  name: id
                  type: bigint
                  autoIncrement: true
                  constraints:
                    primaryKey: true
                    nullable: false
              - column:
                  name: email
                  type: text
                  constraints:
                    nullable: false
                    unique: true
                    uniqueConstraintName: uq_users_email
              - column:
                  name: name
                  type: text
                  constraints:
                    nullable: false
              - column:
                  name: active
                  type: boolean
                  defaultValueBoolean: true
                  constraints:
                    nullable: false
              - column:
                  name: created_at
                  type: timestamptz
                  defaultValueComputed: now()
                  constraints:
                    nullable: false
              - column:
                  name: updated_at
                  type: timestamptz
                  defaultValueComputed: now()
                  constraints:
                    nullable: false
        - createIndex:
            tableName: users
            indexName: idx_users_email
            columns:
              - column:
                  name: email
      rollback:
        - dropTable:
            tableName: users
```

### XML

```xml
<?xml version="1.0" encoding="UTF-8"?>
<databaseChangeLog
    xmlns="http://www.liquibase.org/xml/ns/dbchangelog"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.liquibase.org/xml/ns/dbchangelog
        https://www.liquibase.org/xml/ns/dbchangelog/dbchangelog-latest.xsd">

    <changeSet id="001-create-users-table" author="team">
        <createTable tableName="users">
            <column name="id" type="bigint" autoIncrement="true">
                <constraints primaryKey="true" nullable="false"/>
            </column>
            <column name="email" type="text">
                <constraints nullable="false" unique="true"
                    uniqueConstraintName="uq_users_email"/>
            </column>
            <column name="name" type="text">
                <constraints nullable="false"/>
            </column>
            <column name="created_at" type="timestamptz" defaultValueComputed="now()">
                <constraints nullable="false"/>
            </column>
        </createTable>

        <rollback>
            <dropTable tableName="users"/>
        </rollback>
    </changeSet>
</databaseChangeLog>
```

### SQL Changeset Format

```sql
-- db/changelog/changes/003-add-phone.sql

-- changeset team:003-add-phone-column
ALTER TABLE users ADD COLUMN phone text;
-- rollback ALTER TABLE users DROP COLUMN phone;

-- changeset team:003-add-phone-index context:prod
CREATE INDEX idx_users_phone ON users (phone);
-- rollback DROP INDEX idx_users_phone;
```

## Changeset Attributes

| Attribute   | Description                | Example                       |
|-------------|----------------------------|-------------------------------|
| id          | Unique identifier          | `001-create-users`            |
| author      | Who created it             | `team`                        |
| context     | Environment filter         | `dev`, `prod`, `!test`        |
| labels      | Label-based filter         | `feature-auth`, `v1.0`        |
| runOnChange | Re-run if checksum changes | `true` (for views, functions) |
| runAlways   | Run every time             | `true` (rarely needed)        |
| failOnError | Fail migration on error    | `true` (default)              |
| dbms        | Database filter            | `postgresql`, `!h2`           |

## Common Change Types

### Table Operations

```yaml
# Create table (see full example above)
- createTable:
    tableName: orders

# Add column
- changeSet:
    id: 002-add-phone
    author: team
    changes:
      - addColumn:
          tableName: users
          columns:
            - column:
                name: phone
                type: text

# Drop column
- changeSet:
    id: 003-drop-legacy-field
    author: team
    changes:
      - dropColumn:
          tableName: users
          columnName: legacy_field
    rollback:
      - addColumn:
          tableName: users
          columns:
            - column:
                name: legacy_field
                type: text
```

### Index Operations

```yaml
- changeSet:
    id: 004-create-orders-index
    author: team
    changes:
      - createIndex:
          tableName: orders
          indexName: idx_orders_user_id
          columns:
            - column:
                name: user_id
    rollback:
      - dropIndex:
          tableName: orders
          indexName: idx_orders_user_id
```

### Foreign Key Constraints

```yaml
- changeSet:
    id: 005-add-fk-orders-users
    author: team
    changes:
      - addForeignKeyConstraint:
          baseTableName: orders
          baseColumnNames: user_id
          referencedTableName: users
          referencedColumnNames: id
          constraintName: fk_orders_user_id
          onDelete: CASCADE
    rollback:
      - dropForeignKeyConstraint:
          baseTableName: orders
          constraintName: fk_orders_user_id
```

## Rollback

### Automatic Rollback

These change types have automatic rollback support:

- `createTable` -> drops the table
- `addColumn` -> drops the column
- `createIndex` -> drops the index
- `addForeignKeyConstraint` -> drops the constraint

### Explicit Rollback

```yaml
- changeSet:
    id: 006-data-migration
    author: team
    changes:
      - sql:
          sql: UPDATE users SET status = 'ACTIVE' WHERE status IS NULL
    rollback:
      - sql:
          sql: UPDATE users SET status = NULL WHERE status = 'ACTIVE'
```

### Empty Rollback (intentionally not rollbackable)

```yaml
- changeSet:
    id: 007-drop-old-data
    author: team
    changes:
      - sql:
          sql: DELETE FROM audit_log WHERE created_at < '2023-01-01'
    rollback:
      - empty: {}
```

## Contexts and Labels

### Contexts

```yaml
# Only runs in dev context
- changeSet:
    id: 010-seed-test-data
    author: team
    context: dev
    changes:
      - sql:
          sql: INSERT INTO users (email, name) VALUES ('dev@test.com', 'Dev User')

# Runs in prod and staging, but not dev
- changeSet:
    id: 011-production-index
    author: team
    context: prod or staging
    changes:
      - createIndex:
          tableName: orders
          indexName: idx_orders_compound
          columns:
            - column: { name: user_id }
            - column: { name: status }
```

### Spring Boot Context Configuration

```yaml
spring:
  liquibase:
    contexts: prod  # or dev, test
```

### Labels (more flexible than contexts)

```yaml
- changeSet:
    id: 012-feature-auth
    author: team
    labels: feature-auth, v2.0
    changes:
      - createTable:
          tableName: auth_tokens
```

## Preconditions

```yaml
- changeSet:
    id: 020-add-column-if-not-exists
    author: team
    preConditions:
      - onFail: MARK_RAN
      - not:
          - columnExists:
              tableName: users
              columnName: phone
    changes:
      - addColumn:
          tableName: users
          columns:
            - column:
                name: phone
                type: text

- changeSet:
    id: 021-postgresql-only
    author: team
    preConditions:
      - dbms:
          type: postgresql
    changes:
      - sql:
          sql: CREATE EXTENSION IF NOT EXISTS "uuid-ossp"
```

### Precondition onFail Options

| Option   | Behavior                      |
|----------|-------------------------------|
| HALT     | Stop execution (default)      |
| CONTINUE | Skip this changeset, try next |
| MARK_RAN | Skip but mark as executed     |
| WARN     | Log warning, continue         |

## Spring Boot Integration

### application.yml

```yaml
spring:
  liquibase:
    enabled: true
    change-log: classpath:db/changelog/db.changelog-master.yaml
    default-schema: public
    contexts: ${LIQUIBASE_CONTEXTS:prod}
    drop-first: false          # NEVER true in production
    clear-checksums: false
```

### Dependencies

```kotlin
// build.gradle.kts
dependencies {
    implementation("org.liquibase:liquibase-core")
    // Spring Boot auto-configures Liquibase when this is on classpath
}
```

## Master Changelog with Includes

```yaml
# db/changelog/db.changelog-master.yaml
databaseChangeLog:
  # Include specific files in order
  - include:
      file: db/changelog/releases/v1.0/changelog.yaml
  - include:
      file: db/changelog/releases/v1.1/changelog.yaml
  - include:
      file: db/changelog/releases/v2.0/changelog.yaml

  # Or include all files in a directory
  - includeAll:
      path: db/changelog/changes/
      # Files are included in alphabetical order
```

### Recommended Directory Structure

```
src/main/resources/
  db/
    changelog/
      db.changelog-master.yaml
      releases/
        v1.0/
          changelog.yaml
          001-create-users.yaml
          002-create-orders.yaml
        v1.1/
          changelog.yaml
          001-add-phone-column.yaml
        v2.0/
          changelog.yaml
          001-create-auth-tokens.yaml
```

## Gradle Plugin

```kotlin
// build.gradle.kts
plugins {
    id("org.liquibase.gradle") version "2.2.2"
}

dependencies {
    liquibaseRuntime("org.liquibase:liquibase-core:4.27.0")
    liquibaseRuntime("org.liquibase:liquibase-groovy-dsl:4.0.0")
    liquibaseRuntime("org.postgresql:postgresql:42.7.3")
}

liquibase {
    activities {
        register("main") {
            arguments = mapOf(
                "changeLogFile" to "src/main/resources/db/changelog/db.changelog-master.yaml",
                "url" to "jdbc:postgresql://localhost:5432/mydb",
                "username" to "postgres",
                "password" to "postgres"
            )
        }
    }
}
```

### Tasks

```bash
./gradlew update             # Apply pending changesets
./gradlew rollbackCount -PliquibaseCommandValue=1  # Rollback last changeset
./gradlew status             # Show pending changesets
./gradlew diff               # Compare database to reference
./gradlew generateChangelog  # Generate changelog from existing DB
./gradlew clearChecksums     # Clear stored checksums
./gradlew tag -PliquibaseCommandValue=v1.0  # Tag current state
./gradlew rollback -PliquibaseCommandValue=v1.0  # Rollback to tag
```

## Best Practices

1. **One logical change per changeset** -- easier to track, rollback, and debug
2. **Meaningful IDs** -- use descriptive IDs like `001-create-users`, not auto-generated numbers
3. **Always define rollback** -- even if it is an empty rollback for destructive operations
4. **Use YAML over XML** -- more readable, less verbose
5. **Never modify applied changesets** -- checksum validation will fail
6. **Use runOnChange for views and functions** -- allows updates without new changesets
7. **Explicit constraint names** -- avoid auto-generated names that differ across databases
8. **Test rollbacks in CI** -- run update then rollback to verify
9. **Use contexts for environment-specific data** -- seed data in dev, not prod
10. **Keep changelog files small** -- one changeset per file for large projects
