---
name: postgresql
description: "PostgreSQL: data types, indexing, EXPLAIN, RLS, partitioning, read-only schema analysis"
targets: ["claudecode"]
claudecode:
  model: haiku
---

# PostgreSQL Reference

## Common Data Types

### Numeric

- `smallint` (2 bytes), `integer` (4 bytes), `bigint` (8 bytes) -- prefer `bigint` for IDs
- `numeric(precision, scale)` -- exact, use for money/financial
- `real` (4 bytes), `double precision` (8 bytes) -- approximate, avoid for money

### Text

- `text` -- preferred, no length limit, same performance as varchar
- `varchar(n)` -- only if you need a hard length constraint enforced by DB
- Never use `char(n)` -- pads with spaces, almost never what you want

### Date/Time

- `timestamptz` -- ALWAYS use this, stores UTC internally, converts on display
- `timestamp` (without tz) -- avoid, loses timezone info
- `date`, `time`, `interval` -- for date-only, time-only, durations

### Other

- `uuid` -- use `gen_random_uuid()` (PG 13+), ideal for distributed IDs
- `jsonb` -- binary JSON, indexable with GIN; prefer over `json`
- `boolean` -- true/false/null
- `bytea` -- binary data
- Arrays: `text[]`, `integer[]` -- use sparingly, consider a join table instead

## Indexing

### B-tree (default)

Best for equality and range queries (`=`, `<`, `>`, `BETWEEN`, `ORDER BY`).

```sql
CREATE INDEX idx_users_email ON users (email);
CREATE INDEX idx_orders_created ON orders (created_at DESC);
```

### GIN (Generalized Inverted Index)

Best for jsonb, arrays, full-text search.

```sql
-- jsonb containment queries (@>, ?, ?|, ?&)
CREATE INDEX idx_users_metadata ON users USING GIN (metadata);

-- full-text search
CREATE INDEX idx_articles_search ON articles USING GIN (to_tsvector('english', title || ' ' || body));

-- array containment
CREATE INDEX idx_tags ON posts USING GIN (tags);
```

### GiST (Generalized Search Tree)

Best for geometric data, range types, proximity queries.

```sql
CREATE INDEX idx_locations ON places USING GiST (point_column);
CREATE INDEX idx_periods ON events USING GiST (tstzrange(start_at, end_at));
```

### Partial Indexes

Index only rows matching a condition -- smaller, faster.

```sql
CREATE INDEX idx_orders_pending ON orders (created_at)
  WHERE status = 'PENDING';
```

### Expression Indexes

Index a computed expression.

```sql
CREATE INDEX idx_users_email_lower ON users (lower(email));
```

### CONCURRENTLY

Add indexes without locking writes. Always use in production migrations.

```sql
CREATE INDEX CONCURRENTLY idx_users_email ON users (email);
```

**Caveats:** Cannot run inside a transaction. May leave an INVALID index on failure -- check with `\d tablename` and drop if invalid.

## EXPLAIN ANALYZE

### Reading Execution Plans

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM orders WHERE user_id = 42 AND status = 'PENDING';
```

Key metrics:

- **actual time**: first row..last row in ms
- **rows**: actual vs estimated (big difference = stale statistics, run `ANALYZE`)
- **Buffers shared hit**: pages from cache; **shared read**: from disk
- **Planning Time / Execution Time**: total wall time

### Common Issues

| Symptom                         | Likely Cause                 | Fix                            |
|---------------------------------|------------------------------|--------------------------------|
| Seq Scan on large table         | Missing index                | Add appropriate index          |
| Nested Loop with high row count | Missing index on join column | Index the FK column            |
| Hash Join with huge build       | Large intermediate result    | Add WHERE filters, limit joins |
| Sort with high cost             | ORDER BY without index       | Add index matching sort order  |
| Bitmap Heap Scan recheck        | Low work_mem                 | Increase work_mem              |

## Row Level Security (RLS)

### Enable RLS

```sql
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;

-- Force RLS even for table owner (recommended for testing)
ALTER TABLE documents FORCE ROW LEVEL SECURITY;
```

### Common Policies

```sql
-- Users can only see their own rows
CREATE POLICY user_isolation ON documents
  FOR ALL
  USING (user_id = current_setting('app.current_user_id')::bigint);

-- Read-only policy for a role
CREATE POLICY readonly_policy ON documents
  FOR SELECT
  TO readonly_role
  USING (true);

-- Insert policy: ensure user_id matches on insert
CREATE POLICY insert_own ON documents
  FOR INSERT
  WITH CHECK (user_id = current_setting('app.current_user_id')::bigint);
```

### Setting Context for RLS

```kotlin
// In your application, set the session variable before queries
dslContext.execute("SET LOCAL app.current_user_id = '${userId}'")
```

```java
// Java/JDBC
connection.createStatement().execute(
    "SET LOCAL app.current_user_id = '" + userId + "'"
);
```

## Partitioning

### When to Use

- Tables with 10M+ rows
- Queries commonly filter on the partition key
- Need to efficiently drop old data (detach + drop partition)

### Range Partitioning (most common)

```sql
CREATE TABLE events (
    id         bigint GENERATED ALWAYS AS IDENTITY,
    event_type text NOT NULL,
    created_at timestamptz NOT NULL,
    payload    jsonb
) PARTITION BY RANGE (created_at);

CREATE TABLE events_2024_q1 PARTITION OF events
  FOR VALUES FROM ('2024-01-01') TO ('2024-04-01');
CREATE TABLE events_2024_q2 PARTITION OF events
  FOR VALUES FROM ('2024-04-01') TO ('2024-07-01');
```

### List Partitioning

```sql
CREATE TABLE orders (
    id     bigint,
    region text NOT NULL,
    total  numeric
) PARTITION BY LIST (region);

CREATE TABLE orders_eu PARTITION OF orders FOR VALUES IN ('EU');
CREATE TABLE orders_us PARTITION OF orders FOR VALUES IN ('US');
```

### Hash Partitioning

For even distribution when no natural range/list key.

```sql
CREATE TABLE sessions (
    id      uuid PRIMARY KEY,
    data    jsonb
) PARTITION BY HASH (id);

CREATE TABLE sessions_0 PARTITION OF sessions FOR VALUES WITH (MODULUS 4, REMAINDER 0);
CREATE TABLE sessions_1 PARTITION OF sessions FOR VALUES WITH (MODULUS 4, REMAINDER 1);
```

## Common Anti-Patterns

1. **SELECT \*** -- fetch only needed columns, especially with wide tables or jsonb
2. **Wrong data types** -- `varchar(255)` out of habit; use `text`. `integer` for IDs that may exceed 2B; use `bigint`
3. **OFFSET pagination on large tables** -- O(n) cost; use cursor-based pagination instead
4. **Unparameterized queries** -- SQL injection risk AND prevents plan caching
5. **Missing indexes on foreign keys** -- every FK column needs an index for JOIN and CASCADE performance
6. **Not using `timestamptz`** -- `timestamp` silently drops timezone info
7. **Storing money as float** -- use `numeric(19,4)` or integer cents

## Cursor-Based Pagination vs OFFSET

### OFFSET (avoid for large datasets)

```sql
-- Scans and discards first 10000 rows every time
SELECT * FROM orders ORDER BY id LIMIT 20 OFFSET 10000;
```

### Cursor-Based (preferred)

```sql
-- Client passes the last seen ID
SELECT * FROM orders WHERE id > :last_seen_id ORDER BY id LIMIT 20;
```

```kotlin
// Kotlin/Spring example
@GetMapping("/orders")
fun getOrders(@RequestParam cursor: Long?, @RequestParam size: Int = 20): Page {
    val orders = if (cursor != null) {
        orderRepository.findByIdGreaterThanOrderByIdAsc(cursor, PageRequest.of(0, size))
    } else {
        orderRepository.findAllByOrderByIdAsc(PageRequest.of(0, size))
    }
    val nextCursor = orders.lastOrNull()?.id
    return Page(data = orders, nextCursor = nextCursor)
}
```

```java
// Java/Spring example
@GetMapping("/orders")
public Page getOrders(
        @RequestParam(required = false) Long cursor,
        @RequestParam(defaultValue = "20") int size) {
    List<Order> orders = (cursor != null)
        ? orderRepository.findByIdGreaterThanOrderByIdAsc(cursor, PageRequest.of(0, size))
        : orderRepository.findAllByOrderByIdAsc(PageRequest.of(0, size));
    Long nextCursor = orders.isEmpty() ? null : orders.get(orders.size() - 1).getId();
    return new Page(orders, nextCursor);
}
```

## Configuration Tuning

| Parameter              | Rule of Thumb         | Notes                                                     |
|------------------------|-----------------------|-----------------------------------------------------------|
| `shared_buffers`       | 25% of RAM            | Main cache                                                |
| `effective_cache_size` | 50-75% of RAM         | Planner hint, not allocation                              |
| `work_mem`             | 64-256 MB             | Per-sort/hash operation; be careful with many connections |
| `maintenance_work_mem` | 512 MB - 2 GB         | For VACUUM, CREATE INDEX                                  |
| `random_page_cost`     | 1.1 (SSD) / 4.0 (HDD) | Affects index vs seq scan decisions                       |
| `max_connections`      | Use pgbouncer         | Don't set to 500+; use connection pooling                 |

## Diagnostic Queries

### Table Sizes

```sql
SELECT schemaname, tablename,
       pg_size_pretty(pg_total_relation_size(schemaname || '.' || tablename)) AS total_size,
       pg_size_pretty(pg_relation_size(schemaname || '.' || tablename)) AS table_size,
       pg_size_pretty(pg_indexes_size(schemaname || '.' || tablename)) AS index_size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname || '.' || tablename) DESC;
```

### Index Usage

```sql
SELECT indexrelname, idx_scan, idx_tup_read, idx_tup_fetch,
       pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
ORDER BY idx_scan ASC;
-- Low idx_scan = potentially unused index (candidate for removal)
```

### Slow Queries (requires pg_stat_statements)

```sql
SELECT query, calls, mean_exec_time, total_exec_time,
       rows / calls AS avg_rows
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 20;
```

### Active Locks

```sql
SELECT pid, usename, state, query, wait_event_type, wait_event,
       now() - query_start AS duration
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY duration DESC;
```

### Bloat Estimation

```sql
SELECT schemaname, tablename,
       n_dead_tup,
       n_live_tup,
       round(n_dead_tup::numeric / NULLIF(n_live_tup, 0) * 100, 2) AS dead_pct
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC;
```

## Read-Only Schema Analysis

### pg_catalog Queries

```sql
-- List all tables with column counts
SELECT t.table_name, count(c.column_name) AS col_count
FROM information_schema.tables t
JOIN information_schema.columns c ON t.table_name = c.table_name AND t.table_schema = c.table_schema
WHERE t.table_schema = 'public' AND t.table_type = 'BASE TABLE'
GROUP BY t.table_name
ORDER BY t.table_name;

-- List all foreign keys
SELECT tc.table_name, kcu.column_name,
       ccu.table_name AS foreign_table, ccu.column_name AS foreign_column
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name = ccu.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_schema = 'public';

-- List all indexes with their columns
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;
```

### psql Commands Reference

```
\dt          -- list tables
\dt+         -- list tables with sizes
\d tablename -- describe table (columns, indexes, constraints)
\di          -- list indexes
\df          -- list functions
\dn          -- list schemas
\du          -- list roles
```
