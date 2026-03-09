---
name: flyway
description: "Flyway: migration naming, versioned/repeatable, callbacks, undo migrations, Spring Boot integration"
targets: ["claudecode"]
claudecode:
  model: haiku
---

# Flyway Migration Reference

## Migration Naming Convention

### Versioned Migrations

Format: `V{version}__{description}.sql`

```
V1__create_users_table.sql
V1.1__add_email_index.sql
V2__create_orders_table.sql
V2.1__add_orders_status_column.sql
```

- Double underscore `__` separates version from description
- Version can use dots (1.1) or underscores as separators
- Description uses underscores, becomes human-readable in schema history
- Versions are sorted lexicographically -- `V1.1` comes before `V1.10`

### Repeatable Migrations

Format: `R__{description}.sql`

```
R__create_views.sql
R__update_functions.sql
R__refresh_materialized_views.sql
```

- Re-applied whenever their checksum changes
- Always run after all versioned migrations
- Must be idempotent (CREATE OR REPLACE, DROP IF EXISTS + CREATE)

## Spring Boot Integration

### application.yml

```yaml
spring:
  flyway:
    enabled: true
    locations: classpath:db/migration
    baseline-on-migrate: false
    clean-disabled: true        # ALWAYS true in production
    validate-on-migrate: true
    out-of-order: false          # set true only for team development
    table: flyway_schema_history
    schemas: public
```

### Directory Structure

```
src/main/resources/
  db/
    migration/
      V1__create_users_table.sql
      V1.1__add_email_to_users.sql
      V2__create_orders_table.sql
      R__create_views.sql
    callbacks/
      afterMigrate.sql
```

## Example Migrations

### V1__create_users_table.sql

```sql
CREATE TABLE users (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email      text NOT NULL,
    name       text NOT NULL,
    active     boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_users_email UNIQUE (email)
);

CREATE INDEX idx_users_email ON users (email);
CREATE INDEX idx_users_active ON users (active) WHERE active = true;
```

### V2__create_orders_table.sql

```sql
CREATE TABLE orders (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id    bigint NOT NULL REFERENCES users (id),
    status     text NOT NULL DEFAULT 'PENDING',
    total      numeric(19, 4) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_orders_user_id ON orders (user_id);
CREATE INDEX idx_orders_status ON orders (status);
```

### Adding a Column Safely (PostgreSQL)

```sql
-- V3__add_phone_to_users.sql
-- Step 1: Add nullable column (no lock)
ALTER TABLE users ADD COLUMN phone text;

-- Step 2: Index if needed (CONCURRENTLY to avoid locks)
-- NOTE: CONCURRENTLY cannot run inside a transaction.
-- In Flyway, set the migration to non-transactional.
```

For `CONCURRENTLY`, create a separate non-transactional migration:

```sql
-- V3.1__add_phone_index.sql
-- flyway:executeInTransaction=false
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_phone ON users (phone);
```

## Callbacks

### SQL Callbacks

Place in the migration locations directory:

```sql
-- afterMigrate.sql
-- Runs after every successful migration
ANALYZE;
```

```sql
-- beforeMigrate.sql
-- Runs before migrations start
-- Useful for setting search_path or session variables
SET search_path TO public;
```

### Available Callback Events

| Callback            | When                                    |
|---------------------|-----------------------------------------|
| beforeMigrate       | Before migrations run                   |
| afterMigrate        | After all migrations complete           |
| afterMigrateApplied | After migrations applied (not on no-op) |
| afterMigrateError   | After migration failure                 |
| beforeEachMigrate   | Before each individual migration        |
| afterEachMigrate    | After each individual migration         |
| beforeClean         | Before clean                            |
| afterClean          | After clean                             |
| beforeValidate      | Before validation                       |
| afterValidate       | After validation                        |

### Java Callbacks

```kotlin
// Kotlin
@Component
class AfterMigrateCallback : Callback {
    override fun supports(event: Event, context: Context): Boolean =
        event == Event.AFTER_MIGRATE

    override fun canHandleInTransaction(event: Event, context: Context): Boolean = true

    override fun handle(event: Event, context: Context) {
        // Custom logic after migration
        context.connection.createStatement().use { stmt ->
            stmt.execute("REFRESH MATERIALIZED VIEW CONCURRENTLY mv_user_stats")
        }
    }

    override fun getCallbackName(): String = "afterMigrateCallback"
}
```

```java
// Java
@Component
public class AfterMigrateCallback implements Callback {
    @Override
    public boolean supports(Event event, Context context) {
        return event == Event.AFTER_MIGRATE;
    }

    @Override
    public boolean canHandleInTransaction(Event event, Context context) {
        return true;
    }

    @Override
    public void handle(Event event, Context context) {
        try (var stmt = context.getConnection().createStatement()) {
            stmt.execute("REFRESH MATERIALIZED VIEW CONCURRENTLY mv_user_stats");
        } catch (SQLException e) {
            throw new RuntimeException("Failed to refresh materialized view", e);
        }
    }

    @Override
    public String getCallbackName() {
        return "afterMigrateCallback";
    }
}
```

## Baseline for Existing Databases

When adopting Flyway on an existing database:

```yaml
spring:
  flyway:
    baseline-on-migrate: true
    baseline-version: 1
    baseline-description: "Baseline existing schema"
```

All migrations with version <= baseline-version are skipped.

## Undo Migrations (Flyway Teams)

Format: `U{version}__{description}.sql`

```sql
-- U2__create_orders_table.sql
DROP TABLE IF EXISTS orders;
```

**Warning:** Undo migrations are a paid feature. In open-source Flyway, use forward-only migrations: create a new versioned migration that
reverses the change.

## Clean

```yaml
# NEVER in production
spring:
  flyway:
    clean-disabled: true  # default in Spring Boot
```

Use only for:

- Local development reset
- CI/CD test database reset

## Gradle Plugin

```kotlin
// build.gradle.kts
plugins {
    id("org.flywaydb.flyway") version "10.10.0"
}

flyway {
    url = "jdbc:postgresql://localhost:5432/mydb"
    user = "postgres"
    password = "postgres"
    schemas = arrayOf("public")
    locations = arrayOf("classpath:db/migration")
}
```

### Tasks

```bash
./gradlew flywayInfo       # Show migration status
./gradlew flywayMigrate    # Apply pending migrations
./gradlew flywayValidate   # Validate applied migrations
./gradlew flywayClean      # Drop all objects (DEV ONLY)
./gradlew flywayBaseline   # Baseline existing database
./gradlew flywayRepair     # Fix schema history table
```

## Java-Based Migrations

For complex migrations that need procedural logic:

```kotlin
// Kotlin - V4__migrate_user_data.kt
package db.migration

import org.flywaydb.core.api.migration.BaseJavaMigration
import org.flywaydb.core.api.migration.Context

class V4__migrate_user_data : BaseJavaMigration() {
    override fun migrate(context: Context) {
        context.connection.createStatement().use { stmt ->
            val rs = stmt.executeQuery("SELECT id, full_name FROM users WHERE first_name IS NULL")
            val update = context.connection.prepareStatement(
                "UPDATE users SET first_name = ?, last_name = ? WHERE id = ?"
            )
            while (rs.next()) {
                val parts = rs.getString("full_name").split(" ", limit = 2)
                update.setString(1, parts[0])
                update.setString(2, parts.getOrElse(1) { "" })
                update.setLong(3, rs.getLong("id"))
                update.addBatch()
            }
            update.executeBatch()
        }
    }
}
```

```java
// Java - V4__migrate_user_data.java
package db.migration;

import org.flywaydb.core.api.migration.BaseJavaMigration;
import org.flywaydb.core.api.migration.Context;
import java.sql.*;

public class V4__migrate_user_data extends BaseJavaMigration {
    @Override
    public void migrate(Context context) throws Exception {
        try (Statement stmt = context.getConnection().createStatement()) {
            ResultSet rs = stmt.executeQuery(
                "SELECT id, full_name FROM users WHERE first_name IS NULL"
            );
            PreparedStatement update = context.getConnection().prepareStatement(
                "UPDATE users SET first_name = ?, last_name = ? WHERE id = ?"
            );
            while (rs.next()) {
                String[] parts = rs.getString("full_name").split(" ", 2);
                update.setString(1, parts[0]);
                update.setString(2, parts.length > 1 ? parts[1] : "");
                update.setLong(3, rs.getLong("id"));
                update.addBatch();
            }
            update.executeBatch();
        }
    }
}
```

## Best Practices

1. **One change per migration** -- easier to debug, rollback, and understand
2. **Never modify an applied migration** -- create a new one instead
3. **Idempotent repeatable migrations** -- use `CREATE OR REPLACE`, `DROP IF EXISTS`
4. **Forward-only in production** -- no undo, no clean, no baseline changes
5. **Add columns as nullable first** -- avoids table locks on large tables
6. **Use CONCURRENTLY for indexes** -- in a separate non-transactional migration
7. **Test migrations against a copy of production data** -- sizes matter
8. **Version control your migrations** -- they are source code
9. **Name constraints explicitly** -- auto-generated names are database-specific
10. **Set clean-disabled=true** -- always, especially in shared environments
