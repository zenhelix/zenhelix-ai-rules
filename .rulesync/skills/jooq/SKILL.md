---
name: jooq
description: "jOOQ: code generation, typesafe queries, Kotlin/Java DSL, transactions, integration with JPA"
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# jOOQ Reference

## Code Generation

### Gradle Plugin Setup

```kotlin
// build.gradle.kts
plugins {
    id("nu.studer.jooq") version "9.0"
}

dependencies {
    jooqGenerator("org.postgresql:postgresql:42.7.3")
}

jooq {
    version.set("3.19.6")
    configurations {
        create("main") {
            jooqConfiguration.apply {
                jdbc.apply {
                    driver = "org.postgresql.Driver"
                    url = "jdbc:postgresql://localhost:5432/mydb"
                    user = "postgres"
                    password = "postgres"
                }
                generator.apply {
                    name = "org.jooq.codegen.KotlinGenerator" // or JavaGenerator
                    database.apply {
                        name = "org.jooq.meta.postgres.PostgresDatabase"
                        inputSchema = "public"
                        excludes = "flyway_schema_history"
                    }
                    generate.apply {
                        isDeprecated = false
                        isRecords = true
                        isPojos = true
                        isImmutablePojos = true
                        isFluentSetters = true
                        isDaos = true
                        isKotlinNotNullPojoAttributes = true
                        isKotlinNotNullRecordAttributes = true
                    }
                    target.apply {
                        packageName = "com.example.generated.jooq"
                        directory = "build/generated-src/jooq/main"
                    }
                }
            }
        }
    }
}
```

### Maven Plugin Setup

```xml
<plugin>
    <groupId>org.jooq</groupId>
    <artifactId>jooq-codegen-maven</artifactId>
    <version>3.19.6</version>
    <executions>
        <execution>
            <goals><goal>generate</goal></goals>
        </execution>
    </executions>
    <configuration>
        <jdbc>
            <driver>org.postgresql.Driver</driver>
            <url>jdbc:postgresql://localhost:5432/mydb</url>
            <user>postgres</user>
            <password>postgres</password>
        </jdbc>
        <generator>
            <database>
                <name>org.jooq.meta.postgres.PostgresDatabase</name>
                <inputSchema>public</inputSchema>
            </database>
            <target>
                <packageName>com.example.generated.jooq</packageName>
            </target>
        </generator>
    </configuration>
</plugin>
```

## Basic CRUD

### Select

```kotlin
// Kotlin
import com.example.generated.jooq.Tables.USERS

// Single record
val user = dsl.selectFrom(USERS)
    .where(USERS.ID.eq(userId))
    .fetchOne()

// Multiple records with specific columns
val names = dsl.select(USERS.ID, USERS.EMAIL, USERS.NAME)
    .from(USERS)
    .where(USERS.ACTIVE.isTrue)
    .orderBy(USERS.NAME.asc())
    .fetch()

// Fetch into a DTO
data class UserDto(val id: Long, val email: String, val name: String)

val users = dsl.select(USERS.ID, USERS.EMAIL, USERS.NAME)
    .from(USERS)
    .fetchInto(UserDto::class.java)
```

```java
// Java
import static com.example.generated.jooq.Tables.USERS;

// Single record
UsersRecord user = dsl.selectFrom(USERS)
    .where(USERS.ID.eq(userId))
    .fetchOne();

// Multiple records
Result<Record3<Long, String, String>> result = dsl
    .select(USERS.ID, USERS.EMAIL, USERS.NAME)
    .from(USERS)
    .where(USERS.ACTIVE.isTrue())
    .orderBy(USERS.NAME.asc())
    .fetch();

// Fetch into a DTO
List<UserDto> users = dsl.select(USERS.ID, USERS.EMAIL, USERS.NAME)
    .from(USERS)
    .fetchInto(UserDto.class);
```

### Insert

```kotlin
// Kotlin - using record
val record = dsl.newRecord(USERS).apply {
    email = "user@example.com"
    name = "John"
}
record.store()

// Kotlin - using DSL (returns generated ID)
val id = dsl.insertInto(USERS)
    .set(USERS.EMAIL, "user@example.com")
    .set(USERS.NAME, "John")
    .returning(USERS.ID)
    .fetchOne()!!
    .id
```

```java
// Java
Long id = dsl.insertInto(USERS)
    .set(USERS.EMAIL, "user@example.com")
    .set(USERS.NAME, "John")
    .returning(USERS.ID)
    .fetchOne()
    .getId();
```

### Update

```kotlin
// Kotlin
val rowsAffected = dsl.update(USERS)
    .set(USERS.NAME, "Jane")
    .set(USERS.UPDATED_AT, OffsetDateTime.now())
    .where(USERS.ID.eq(userId))
    .execute()
```

```java
// Java
int rowsAffected = dsl.update(USERS)
    .set(USERS.NAME, "Jane")
    .set(USERS.UPDATED_AT, OffsetDateTime.now())
    .where(USERS.ID.eq(userId))
    .execute();
```

### Delete

```kotlin
// Kotlin
val deleted = dsl.deleteFrom(USERS)
    .where(USERS.ID.eq(userId))
    .execute()
```

## Type-Safe Conditions

```kotlin
// Kotlin - building conditions dynamically
fun searchUsers(email: String?, name: String?, active: Boolean?): List<UserDto> {
    var condition = DSL.noCondition()

    email?.let { condition = condition.and(USERS.EMAIL.eq(it)) }
    name?.let { condition = condition.and(USERS.NAME.likeIgnoreCase("%$it%")) }
    active?.let { condition = condition.and(USERS.ACTIVE.eq(it)) }

    return dsl.selectFrom(USERS)
        .where(condition)
        .fetchInto(UserDto::class.java)
}
```

```java
// Java - building conditions dynamically
public List<UserDto> searchUsers(String email, String name, Boolean active) {
    Condition condition = DSL.noCondition();

    if (email != null) condition = condition.and(USERS.EMAIL.eq(email));
    if (name != null) condition = condition.and(USERS.NAME.likeIgnoreCase("%" + name + "%"));
    if (active != null) condition = condition.and(USERS.ACTIVE.eq(active));

    return dsl.selectFrom(USERS)
        .where(condition)
        .fetchInto(UserDto.class);
}
```

### Common Condition Methods

```kotlin
USERS.EMAIL.eq("value")                // =
USERS.EMAIL.ne("value")                // !=
USERS.AGE.gt(18)                       // >
USERS.AGE.ge(18)                       // >=
USERS.AGE.lt(65)                       // <
USERS.AGE.between(18, 65)             // BETWEEN
USERS.EMAIL.like("%@example.com")      // LIKE
USERS.EMAIL.likeIgnoreCase("%test%")   // ILIKE
USERS.STATUS.in_(Status.ACTIVE, Status.PENDING) // IN
USERS.DELETED_AT.isNull                // IS NULL
USERS.DELETED_AT.isNotNull             // IS NOT NULL
```

## Joins

```kotlin
// Kotlin - explicit join
val ordersWithUsers = dsl
    .select(ORDERS.ID, ORDERS.TOTAL, USERS.NAME, USERS.EMAIL)
    .from(ORDERS)
    .join(USERS).on(ORDERS.USER_ID.eq(USERS.ID))
    .where(ORDERS.STATUS.eq("COMPLETED"))
    .fetch()

// Left join
val usersWithOrders = dsl
    .select(USERS.NAME, DSL.count(ORDERS.ID).`as`("order_count"))
    .from(USERS)
    .leftJoin(ORDERS).on(USERS.ID.eq(ORDERS.USER_ID))
    .groupBy(USERS.NAME)
    .fetch()
```

```java
// Java
Result<?> ordersWithUsers = dsl
    .select(ORDERS.ID, ORDERS.TOTAL, USERS.NAME, USERS.EMAIL)
    .from(ORDERS)
    .join(USERS).on(ORDERS.USER_ID.eq(USERS.ID))
    .where(ORDERS.STATUS.eq("COMPLETED"))
    .fetch();
```

## Aggregations

```kotlin
// Kotlin
val stats = dsl
    .select(
        ORDERS.STATUS,
        DSL.count().`as`("count"),
        DSL.sum(ORDERS.TOTAL).`as`("total_sum"),
        DSL.avg(ORDERS.TOTAL).`as`("avg_total")
    )
    .from(ORDERS)
    .groupBy(ORDERS.STATUS)
    .having(DSL.count().gt(10))
    .fetch()
```

## Subqueries and CTEs

```kotlin
// Kotlin - subquery
val highSpenders = dsl.selectFrom(USERS)
    .where(USERS.ID.`in`(
        dsl.select(ORDERS.USER_ID)
            .from(ORDERS)
            .groupBy(ORDERS.USER_ID)
            .having(DSL.sum(ORDERS.TOTAL).gt(BigDecimal("1000")))
    ))
    .fetch()

// CTE (Common Table Expression)
val orderTotals = DSL.name("order_totals").`as`(
    dsl.select(ORDERS.USER_ID, DSL.sum(ORDERS.TOTAL).`as`("total"))
        .from(ORDERS)
        .groupBy(ORDERS.USER_ID)
)

val result = dsl.with(orderTotals)
    .select()
    .from(orderTotals)
    .join(USERS).on(USERS.ID.eq(orderTotals.field("user_id", Long::class.java)))
    .where(orderTotals.field("total", BigDecimal::class.java)!!.gt(BigDecimal("500")))
    .fetch()
```

## Transaction Management

### With jOOQ API

```kotlin
// Kotlin
val result = dsl.transactionResult { config ->
    val txDsl = DSL.using(config)

    val userId = txDsl.insertInto(USERS)
        .set(USERS.EMAIL, "new@example.com")
        .returning(USERS.ID)
        .fetchOne()!!.id

    txDsl.insertInto(ORDERS)
        .set(ORDERS.USER_ID, userId)
        .set(ORDERS.TOTAL, BigDecimal("99.99"))
        .execute()

    userId
}
```

```java
// Java
Long result = dsl.transactionResult(config -> {
    DSLContext txDsl = DSL.using(config);

    Long userId = txDsl.insertInto(USERS)
        .set(USERS.EMAIL, "new@example.com")
        .returning(USERS.ID)
        .fetchOne()
        .getId();

    txDsl.insertInto(ORDERS)
        .set(ORDERS.USER_ID, userId)
        .set(ORDERS.TOTAL, BigDecimal.valueOf(99.99))
        .execute();

    return userId;
});
```

### With Spring @Transactional

```kotlin
// Kotlin - Spring integration
@Service
class OrderService(private val dsl: DSLContext) {

    @Transactional
    fun createOrder(userId: Long, total: BigDecimal): Long {
        return dsl.insertInto(ORDERS)
            .set(ORDERS.USER_ID, userId)
            .set(ORDERS.TOTAL, total)
            .returning(ORDERS.ID)
            .fetchOne()!!.id
    }
}
```

## Batch Operations

```kotlin
// Kotlin - batch insert
dsl.batch(
    users.map { user ->
        dsl.insertInto(USERS)
            .set(USERS.EMAIL, user.email)
            .set(USERS.NAME, user.name)
    }
).execute()

// Bulk insert with VALUES
dsl.insertInto(USERS, USERS.EMAIL, USERS.NAME)
    .apply { users.forEach { values(it.email, it.name) } }
    .execute()
```

```java
// Java - batch insert
dsl.batch(
    users.stream()
        .map(user -> dsl.insertInto(USERS)
            .set(USERS.EMAIL, user.getEmail())
            .set(USERS.NAME, user.getName()))
        .collect(Collectors.toList())
).execute();
```

## jOOQ Alongside JPA (Read/Write Split)

Use jOOQ for complex reads, JPA for writes.

```kotlin
// Kotlin
@Service
class UserService(
    private val userRepository: UserRepository,  // JPA for writes
    private val dsl: DSLContext                   // jOOQ for reads
) {
    // Complex read with jOOQ
    fun getUserDashboard(userId: Long): DashboardDto {
        return dsl.select(
            USERS.NAME,
            DSL.count(ORDERS.ID).`as`("order_count"),
            DSL.sum(ORDERS.TOTAL).`as`("total_spent")
        )
        .from(USERS)
        .leftJoin(ORDERS).on(USERS.ID.eq(ORDERS.USER_ID))
        .where(USERS.ID.eq(userId))
        .groupBy(USERS.NAME)
        .fetchOneInto(DashboardDto::class.java)!!
    }

    // Simple write with JPA
    fun createUser(request: CreateUserRequest): User {
        return userRepository.save(User(email = request.email, name = request.name))
    }
}
```

## Record Mapping to DTOs

```kotlin
// Kotlin - custom RecordMapper
val mapper = RecordMapper<Record, UserDto> { record ->
    UserDto(
        id = record[USERS.ID],
        email = record[USERS.EMAIL],
        name = record[USERS.NAME]
    )
}

val users = dsl.selectFrom(USERS).fetch(mapper)

// Or use fetchInto with matching field names
data class UserDto(val id: Long, val email: String, val name: String)
val users = dsl.selectFrom(USERS).fetchInto(UserDto::class.java)
```

## Testing with TestContainers

```kotlin
// Kotlin - TestContainers setup
@Testcontainers
class UserRepositoryTest {

    companion object {
        @Container
        val postgres = PostgreSQLContainer("postgres:16-alpine")
            .withDatabaseName("testdb")

        @JvmStatic
        @DynamicPropertySource
        fun properties(registry: DynamicPropertyRegistry) {
            registry.add("spring.datasource.url") { postgres.jdbcUrl }
            registry.add("spring.datasource.username") { postgres.username }
            registry.add("spring.datasource.password") { postgres.password }
        }
    }

    @Autowired
    lateinit var dsl: DSLContext

    @Test
    fun `should insert and fetch user`() {
        val id = dsl.insertInto(USERS)
            .set(USERS.EMAIL, "test@example.com")
            .set(USERS.NAME, "Test User")
            .returning(USERS.ID)
            .fetchOne()!!.id

        val user = dsl.selectFrom(USERS).where(USERS.ID.eq(id)).fetchOne()

        assertThat(user).isNotNull
        assertThat(user!!.email).isEqualTo("test@example.com")
    }
}
```

```java
// Java - TestContainers setup
@Testcontainers
class UserRepositoryTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine")
        .withDatabaseName("testdb");

    @DynamicPropertySource
    static void properties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired
    DSLContext dsl;

    @Test
    void shouldInsertAndFetchUser() {
        Long id = dsl.insertInto(USERS)
            .set(USERS.EMAIL, "test@example.com")
            .set(USERS.NAME, "Test User")
            .returning(USERS.ID)
            .fetchOne()
            .getId();

        UsersRecord user = dsl.selectFrom(USERS).where(USERS.ID.eq(id)).fetchOne();

        assertThat(user).isNotNull();
        assertThat(user.getEmail()).isEqualTo("test@example.com");
    }
}
```
