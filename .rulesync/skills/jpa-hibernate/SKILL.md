---
name: jpa-hibernate
description: "JPA/Hibernate: entity mapping, relationships, N+1 prevention, second-level cache, performance"
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# JPA / Hibernate Reference

## Entity Design

### Kotlin Entity

```kotlin
@Entity
@Table(name = "users")
class User(
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long? = null,

    @Column(nullable = false, unique = true)
    val email: String,

    @Column(nullable = false)
    val name: String,

    @Column(nullable = false)
    val active: Boolean = true,

    @Column(name = "created_at", nullable = false, updatable = false)
    val createdAt: OffsetDateTime = OffsetDateTime.now(),

    @Column(name = "updated_at", nullable = false)
    var updatedAt: OffsetDateTime = OffsetDateTime.now(),

    @Version
    val version: Long = 0
)
```

**Kotlin plugins required:**

```kotlin
// build.gradle.kts
plugins {
    kotlin("plugin.jpa") version "2.0.0"     // no-arg constructor
    kotlin("plugin.allopen") version "2.0.0"  // open classes for proxying
}

allOpen {
    annotation("jakarta.persistence.Entity")
    annotation("jakarta.persistence.Embeddable")
    annotation("jakarta.persistence.MappedSuperclass")
}
```

### Java Entity

```java
@Entity
@Table(name = "users")
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private String email;

    @Column(nullable = false)
    private String name;

    @Column(nullable = false)
    private boolean active = true;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt = OffsetDateTime.now();

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt = OffsetDateTime.now();

    @Version
    private Long version;

    protected User() {} // JPA requires no-arg constructor

    public User(String email, String name) {
        this.email = email;
        this.name = name;
    }

    // Getters (no setters for immutability where possible)
    public Long getId() { return id; }
    public String getEmail() { return email; }
    public String getName() { return name; }
    public boolean isActive() { return active; }
    public OffsetDateTime getCreatedAt() { return createdAt; }
    public OffsetDateTime getUpdatedAt() { return updatedAt; }
    public Long getVersion() { return version; }
}
```

### ID Generation Strategies

| Strategy   | Use When                                  | Notes                                          |
|------------|-------------------------------------------|------------------------------------------------|
| `IDENTITY` | PostgreSQL `GENERATED ALWAYS AS IDENTITY` | Simple, auto-increment. Disables batch inserts |
| `SEQUENCE` | Need batch inserts                        | Use `@SequenceGenerator` with `allocationSize` |
| `UUID`     | Distributed systems                       | Use `@UuidGenerator` (Hibernate 6.2+)          |

```kotlin
// UUID generation (Hibernate 6.2+)
@Id
@UuidGenerator
val id: UUID? = null

// Sequence with allocation size for batch performance
@Id
@GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "user_seq")
@SequenceGenerator(name = "user_seq", sequenceName = "user_id_seq", allocationSize = 50)
val id: Long? = null
```

## Column Mapping

### @Enumerated

```kotlin
// String storage (preferred -- survives enum reordering)
@Enumerated(EnumType.STRING)
@Column(nullable = false)
val status: OrderStatus = OrderStatus.PENDING

// Or use a converter for custom DB values
@Convert(converter = OrderStatusConverter::class)
val status: OrderStatus = OrderStatus.PENDING
```

```kotlin
@Converter(autoApply = true)
class OrderStatusConverter : AttributeConverter<OrderStatus, String> {
    override fun convertToDatabaseColumn(attribute: OrderStatus): String = attribute.dbValue
    override fun convertToEntityAttribute(dbData: String): OrderStatus =
        OrderStatus.entries.first { it.dbValue == dbData }
}
```

### @Embedded

```kotlin
@Embeddable
data class Address(
    val street: String = "",
    val city: String = "",
    val zipCode: String = "",
    val country: String = ""
)

@Entity
@Table(name = "users")
class User(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long? = null,

    @Embedded
    val address: Address = Address()
)
```

## Relationships

### @ManyToOne / @OneToMany (Most Common)

```kotlin
// Kotlin - Parent side (User)
@Entity
@Table(name = "users")
class User(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long? = null,

    val name: String,

    @OneToMany(mappedBy = "user", cascade = [CascadeType.ALL], orphanRemoval = true)
    val orders: MutableList<Order> = mutableListOf()
) {
    fun addOrder(order: Order) {
        orders.add(order)
        // order.user is set via constructor
    }
}

// Child side (Order)
@Entity
@Table(name = "orders")
class Order(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long? = null,

    @ManyToOne(fetch = FetchType.LAZY) // ALWAYS LAZY
    @JoinColumn(name = "user_id", nullable = false)
    val user: User,

    val total: BigDecimal
)
```

```java
// Java - Parent side
@Entity
@Table(name = "users")
public class User {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String name;

    @OneToMany(mappedBy = "user", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<Order> orders = new ArrayList<>();

    public void addOrder(Order order) {
        orders.add(order);
    }
}

// Java - Child side
@Entity
@Table(name = "orders")
public class Order {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    private BigDecimal total;
}
```

### @ManyToMany

```kotlin
@Entity
@Table(name = "users")
class User(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long? = null,

    @ManyToMany
    @JoinTable(
        name = "user_roles",
        joinColumns = [JoinColumn(name = "user_id")],
        inverseJoinColumns = [JoinColumn(name = "role_id")]
    )
    val roles: MutableSet<Role> = mutableSetOf()
)
```

**Tip:** For ManyToMany with extra columns on the join table, model the join table as an entity with two @ManyToOne relationships.

## Fetch Types

| Type  | Default For                 | Recommendation  |
|-------|-----------------------------|-----------------|
| LAZY  | `@OneToMany`, `@ManyToMany` | Always use LAZY |
| EAGER | `@ManyToOne`, `@OneToOne`   | Change to LAZY  |

**Rule: ALL relationships should be LAZY. Fetch eagerly only when needed via JOIN FETCH or @EntityGraph.**

```kotlin
// Override the default EAGER on @ManyToOne
@ManyToOne(fetch = FetchType.LAZY)
@JoinColumn(name = "user_id")
val user: User
```

## N+1 Prevention

### The Problem

```kotlin
// This triggers N+1: 1 query for users, N queries for orders
val users = userRepository.findAll()
users.forEach { println(it.orders.size) } // Each access fires a query
```

### Solution 1: JOIN FETCH (JPQL)

```kotlin
interface UserRepository : JpaRepository<User, Long> {
    @Query("SELECT u FROM User u JOIN FETCH u.orders WHERE u.active = true")
    fun findActiveUsersWithOrders(): List<User>
}
```

### Solution 2: @EntityGraph

```kotlin
interface UserRepository : JpaRepository<User, Long> {
    @EntityGraph(attributePaths = ["orders"])
    fun findByActiveTrue(): List<User>

    @EntityGraph(attributePaths = ["orders", "orders.items"])
    fun findByIdWithOrdersAndItems(id: Long): User?
}
```

### Solution 3: @BatchSize

```kotlin
@OneToMany(mappedBy = "user")
@BatchSize(size = 20) // Loads orders for up to 20 users in one query
val orders: MutableList<Order> = mutableListOf()
```

### Solution 4: Subselect Fetch

```kotlin
@OneToMany(mappedBy = "user")
@Fetch(FetchMode.SUBSELECT) // One subselect query for all collections
val orders: MutableList<Order> = mutableListOf()
```

### Which to Use?

| Approach     | Best For                                           |
|--------------|----------------------------------------------------|
| JOIN FETCH   | Specific queries where you know the access pattern |
| @EntityGraph | Spring Data methods, flexible graph loading        |
| @BatchSize   | Global default, reduces N+1 to N/batch queries     |
| SUBSELECT    | Loading all collections for a result set           |

## Second-Level Cache

### Configuration

```yaml
# application.yml
spring:
  jpa:
    properties:
      hibernate:
        cache:
          use_second_level_cache: true
          use_query_cache: true
          region.factory_class: org.hibernate.cache.jcache.JCacheRegionFactory
        javax:
          cache:
            provider: org.ehcache.jsr107.EhcacheCachingProvider
```

### Entity Configuration

```kotlin
@Entity
@Table(name = "categories")
@Cacheable
@Cache(usage = CacheConcurrencyStrategy.READ_WRITE)
class Category(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long? = null,
    val name: String,

    @OneToMany(mappedBy = "category")
    @Cache(usage = CacheConcurrencyStrategy.READ_WRITE)
    val products: MutableList<Product> = mutableListOf()
)
```

### Cache Strategies

| Strategy             | Use Case                                |
|----------------------|-----------------------------------------|
| READ_ONLY            | Immutable reference data                |
| READ_WRITE           | General purpose, read-heavy             |
| NONSTRICT_READ_WRITE | Rarely updated, eventual consistency OK |
| TRANSACTIONAL        | JTA transactions (rare)                 |

## Optimistic Locking

```kotlin
@Entity
class Product(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long? = null,

    var name: String,
    var price: BigDecimal,

    @Version
    val version: Long = 0 // Hibernate increments automatically
)
```

```kotlin
// Handling optimistic lock failure
try {
    productRepository.save(updatedProduct)
} catch (e: OptimisticLockingFailureException) {
    // Reload and retry, or inform user of conflict
    throw ConflictException("Product was modified by another user")
}
```

## Lifecycle Callbacks

```kotlin
@Entity
@Table(name = "users")
class User(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long? = null,

    val email: String,
    var name: String,

    @Column(name = "created_at", updatable = false)
    var createdAt: OffsetDateTime? = null,

    @Column(name = "updated_at")
    var updatedAt: OffsetDateTime? = null
) {
    @PrePersist
    fun prePersist() {
        createdAt = OffsetDateTime.now()
        updatedAt = OffsetDateTime.now()
    }

    @PreUpdate
    fun preUpdate() {
        updatedAt = OffsetDateTime.now()
    }
}
```

Or use a shared `@MappedSuperclass`:

```kotlin
@MappedSuperclass
abstract class BaseEntity {
    @Column(name = "created_at", updatable = false)
    var createdAt: OffsetDateTime? = null

    @Column(name = "updated_at")
    var updatedAt: OffsetDateTime? = null

    @PrePersist
    fun onPrePersist() {
        createdAt = OffsetDateTime.now()
        updatedAt = OffsetDateTime.now()
    }

    @PreUpdate
    fun onPreUpdate() {
        updatedAt = OffsetDateTime.now()
    }
}
```

## HikariCP Configuration

```yaml
spring:
  datasource:
    hikari:
      maximum-pool-size: 20        # Default: 10
      minimum-idle: 5
      idle-timeout: 300000         # 5 min
      max-lifetime: 1800000        # 30 min
      connection-timeout: 30000    # 30 sec
      leak-detection-threshold: 60000  # 1 min - log warning for leaked connections
```

## Hibernate Statistics and Query Logging

```yaml
spring:
  jpa:
    properties:
      hibernate:
        generate_statistics: true   # Dev/test only
        format_sql: true
    show-sql: false                 # Use logging config instead

logging:
  level:
    org.hibernate.SQL: DEBUG                       # Log SQL
    org.hibernate.orm.jdbc.bind: TRACE             # Log bind parameters
    org.hibernate.stat: DEBUG                      # Log statistics
```

## Common Anti-Patterns

1. **EAGER fetch everywhere** -- causes unnecessary joins, use LAZY + fetch when needed
2. **toString() with lazy collections** -- triggers lazy loading outside transaction, causes LazyInitializationException
3. **Open-session-in-view (OSIV)** -- set `spring.jpa.open-in-view=false`; fetch in service layer
4. **Entity as API response** -- use DTOs to avoid exposing internal structure and lazy proxies
5. **equals/hashCode on all fields** -- use business key (e.g., email) or natural id
6. **CascadeType.ALL without orphanRemoval** -- orphans remain in DB
7. **Not using @Version** -- lost updates in concurrent scenarios
8. **Large batch operations via JPA** -- use JDBC or jOOQ for bulk writes

## Entity Equality

```kotlin
// Kotlin - use business key
@Entity
@Table(name = "users")
class User(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long? = null,

    @Column(nullable = false, unique = true)
    val email: String,

    val name: String
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is User) return false
        return email == other.email
    }

    override fun hashCode(): Int = email.hashCode()
}
```

```java
// Java - use business key
@Entity
@Table(name = "users")
public class User {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private String email;

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof User other)) return false;
        return Objects.equals(email, other.email);
    }

    @Override
    public int hashCode() {
        return Objects.hash(email);
    }
}
```

## Kotlin-Specific Considerations

- **Do NOT use `data class` for entities** -- copy() and componentN() break Hibernate proxying
- Use `class` with manual equals/hashCode on business key
- `kotlin-jpa` plugin generates no-arg constructor
- `kotlin-allopen` plugin opens entity classes for proxying
- Use `var` for mutable fields, `val` for immutable (id, createdAt)

## Java-Specific Considerations

- Records (`record`) cannot be JPA entities (no no-arg constructor, final)
- Use Lombok `@Getter` but avoid `@Data` (generates equals on all fields)
- Protected no-arg constructor for JPA, public constructor for application code

## Testing with @DataJpaTest

```kotlin
// Kotlin
@DataJpaTest
@Testcontainers
class UserRepositoryTest {
    companion object {
        @Container
        val postgres = PostgreSQLContainer("postgres:16-alpine")

        @JvmStatic
        @DynamicPropertySource
        fun properties(registry: DynamicPropertyRegistry) {
            registry.add("spring.datasource.url") { postgres.jdbcUrl }
            registry.add("spring.datasource.username") { postgres.username }
            registry.add("spring.datasource.password") { postgres.password }
        }
    }

    @Autowired
    lateinit var userRepository: UserRepository

    @Autowired
    lateinit var entityManager: TestEntityManager

    @Test
    fun `should find user by email`() {
        val user = User(email = "test@example.com", name = "Test")
        entityManager.persistAndFlush(user)
        entityManager.clear() // Clear first-level cache

        val found = userRepository.findByEmail("test@example.com")

        assertThat(found).isNotNull
        assertThat(found!!.name).isEqualTo("Test")
    }
}
```

```java
// Java
@DataJpaTest
@Testcontainers
class UserRepositoryTest {
    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine");

    @DynamicPropertySource
    static void properties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired
    UserRepository userRepository;

    @Autowired
    TestEntityManager entityManager;

    @Test
    void shouldFindUserByEmail() {
        var user = new User("test@example.com", "Test");
        entityManager.persistAndFlush(user);
        entityManager.clear();

        var found = userRepository.findByEmail("test@example.com");

        assertThat(found).isNotNull();
        assertThat(found.getName()).isEqualTo("Test");
    }
}
```
