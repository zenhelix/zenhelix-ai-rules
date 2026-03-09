---
name: spring-data-r2dbc
description: "Spring Data R2DBC: reactive repositories, DatabaseClient, R2DBC patterns"
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Spring Data R2DBC

Comprehensive guide for reactive database access with Spring Data R2DBC: repositories, DatabaseClient, transactions, and coroutine support.

## When to Use R2DBC vs JPA

| Criteria             | R2DBC                              | JPA                                   |
|----------------------|------------------------------------|---------------------------------------|
| Application type     | Reactive/WebFlux                   | Traditional/Web MVC                   |
| ORM features needed  | None (no lazy loading, cascading)  | Full ORM (relationships, caching)     |
| Performance priority | High concurrency, non-blocking I/O | Moderate load, developer productivity |
| Schema complexity    | Simple to moderate                 | Complex with deep relationships       |
| Kotlin style         | Coroutines (suspend/Flow)          | Blocking                              |

Key difference: R2DBC has no lazy loading, no cascading, no entity graphs. Manage relationships manually.

## Entity Mapping

### Kotlin

```kotlin
@Table("orders")
data class Order(
    @Id
    val id: Long? = null,
    val customerId: String,
    val status: OrderStatus = OrderStatus.CREATED,
    val totalAmount: BigDecimal,
    val notes: String? = null,
    @CreatedDate
    val createdAt: Instant? = null,
    @LastModifiedDate
    val updatedAt: Instant? = null
)

@Table("order_items")
data class OrderItem(
    @Id
    val id: Long? = null,
    val orderId: Long,
    val productId: String,
    val quantity: Int,
    val unitPrice: BigDecimal
)
```

### Java

```java
@Table("orders")
public record Order(
    @Id Long id,
    String customerId,
    OrderStatus status,
    BigDecimal totalAmount,
    String notes,
    @CreatedDate Instant createdAt,
    @LastModifiedDate Instant updatedAt
) {
    public Order withStatus(OrderStatus newStatus) {
        return new Order(id, customerId, newStatus, totalAmount, notes, createdAt, updatedAt);
    }
}
```

## Reactive Repositories

### Kotlin (Coroutine Repository)

```kotlin
interface OrderRepository : CoroutineCrudRepository<Order, Long> {

    fun findByCustomerId(customerId: String): Flow<Order>

    fun findByStatus(status: OrderStatus): Flow<Order>

    suspend fun findByCustomerIdAndStatus(customerId: String, status: OrderStatus): Order?

    @Query("SELECT * FROM orders WHERE status = :status ORDER BY created_at DESC LIMIT :limit")
    fun findRecentByStatus(status: OrderStatus, limit: Int): Flow<Order>

    @Query("SELECT * FROM orders WHERE total_amount > :minAmount")
    fun findByMinAmount(minAmount: BigDecimal): Flow<Order>

    @Modifying
    @Query("UPDATE orders SET status = :status WHERE id = :id")
    suspend fun updateStatus(id: Long, status: OrderStatus): Int

    @Modifying
    @Query("DELETE FROM orders WHERE status = 'CANCELLED' AND created_at < :before")
    suspend fun deleteOldCancelled(before: Instant): Int
}
```

### Java (Reactive Repository)

```java
public interface OrderRepository extends ReactiveCrudRepository<Order, Long> {

    Flux<Order> findByCustomerId(String customerId);

    Flux<Order> findByStatus(OrderStatus status);

    Mono<Order> findByCustomerIdAndStatus(String customerId, OrderStatus status);

    @Query("SELECT * FROM orders WHERE status = :status ORDER BY created_at DESC LIMIT :limit")
    Flux<Order> findRecentByStatus(OrderStatus status, int limit);

    @Modifying
    @Query("UPDATE orders SET status = :status WHERE id = :id")
    Mono<Integer> updateStatus(Long id, OrderStatus status);
}
```

## DatabaseClient for Complex Queries

### Kotlin

```kotlin
@Repository
class OrderCustomRepository(
    private val databaseClient: DatabaseClient
) {

    suspend fun findWithItems(orderId: Long): OrderWithItems? {
        val order = databaseClient.sql("SELECT * FROM orders WHERE id = :id")
            .bind("id", orderId)
            .map { row, _ ->
                Order(
                    id = row.get("id", java.lang.Long::class.java)?.toLong(),
                    customerId = row.get("customer_id", String::class.java)!!,
                    status = OrderStatus.valueOf(row.get("status", String::class.java)!!),
                    totalAmount = row.get("total_amount", BigDecimal::class.java)!!
                )
            }
            .awaitOneOrNull() ?: return null

        val items = databaseClient.sql("SELECT * FROM order_items WHERE order_id = :orderId")
            .bind("orderId", orderId)
            .map { row, _ ->
                OrderItem(
                    id = row.get("id", java.lang.Long::class.java)?.toLong(),
                    orderId = row.get("order_id", java.lang.Long::class.java)!!.toLong(),
                    productId = row.get("product_id", String::class.java)!!,
                    quantity = row.get("quantity", Integer::class.java)!!.toInt(),
                    unitPrice = row.get("unit_price", BigDecimal::class.java)!!
                )
            }
            .flow()
            .toList()

        return OrderWithItems(order = order, items = items)
    }

    fun searchOrders(filter: OrderFilter): Flow<Order> {
        val conditions = mutableListOf<String>()
        val bindings = mutableMapOf<String, Any>()

        filter.customerId?.let {
            conditions.add("customer_id = :customerId")
            bindings["customerId"] = it
        }
        filter.status?.let {
            conditions.add("status = :status")
            bindings["status"] = it.name
        }
        filter.minAmount?.let {
            conditions.add("total_amount >= :minAmount")
            bindings["minAmount"] = it
        }

        val where = if (conditions.isNotEmpty()) "WHERE ${conditions.joinToString(" AND ")}" else ""
        val sql = "SELECT * FROM orders $where ORDER BY created_at DESC LIMIT :limit OFFSET :offset"
        bindings["limit"] = filter.size
        bindings["offset"] = filter.page * filter.size

        var spec = databaseClient.sql(sql)
        bindings.forEach { (key, value) -> spec = spec.bind(key, value) }

        return spec.map { row, _ -> mapToOrder(row) }.flow()
    }
}
```

### Java

```java
@Repository
public class OrderCustomRepository {

    private final DatabaseClient databaseClient;

    public OrderCustomRepository(DatabaseClient databaseClient) {
        this.databaseClient = databaseClient;
    }

    public Mono<OrderWithItems> findWithItems(Long orderId) {
        Mono<Order> orderMono = databaseClient.sql("SELECT * FROM orders WHERE id = :id")
            .bind("id", orderId)
            .map((row, metadata) -> new Order(
                row.get("id", Long.class),
                row.get("customer_id", String.class),
                OrderStatus.valueOf(row.get("status", String.class)),
                row.get("total_amount", BigDecimal.class),
                null, null, null
            ))
            .one();

        return orderMono.flatMap(order -> {
            Flux<OrderItem> items = databaseClient.sql("SELECT * FROM order_items WHERE order_id = :orderId")
                .bind("orderId", orderId)
                .map((row, metadata) -> new OrderItem(
                    row.get("id", Long.class),
                    row.get("order_id", Long.class),
                    row.get("product_id", String.class),
                    row.get("quantity", Integer.class),
                    row.get("unit_price", BigDecimal.class)
                ))
                .all();
            return items.collectList().map(itemList -> new OrderWithItems(order, itemList));
        });
    }
}
```

## Transaction Management

### Kotlin

```kotlin
@Service
class OrderService(
    private val orderRepository: OrderRepository,
    private val orderItemRepository: OrderItemRepository,
    private val transactionalOperator: TransactionalOperator
) {

    // Declarative transactions with @Transactional
    @Transactional
    suspend fun createOrder(request: CreateOrderRequest): OrderResponse {
        val order = orderRepository.save(
            Order(customerId = request.customerId, totalAmount = request.totalAmount)
        )
        val items = request.items.map { item ->
            orderItemRepository.save(
                OrderItem(
                    orderId = order.id!!,
                    productId = item.productId,
                    quantity = item.quantity,
                    unitPrice = item.unitPrice
                )
            )
        }
        return OrderResponse(order = order, items = items)
    }

    // Programmatic transactions
    suspend fun transferOrder(fromId: Long, toCustomerId: String): Order {
        return transactionalOperator.executeAndAwait { status ->
            val order = orderRepository.findById(fromId)
                ?: throw EntityNotFoundException("Order $fromId not found")
            val updated = order.copy(customerId = toCustomerId)
            orderRepository.save(updated)
        }!!
    }
}
```

### Java

```java
@Service
public class OrderService {

    private final OrderRepository orderRepository;
    private final TransactionalOperator transactionalOperator;

    @Transactional
    public Mono<OrderResponse> createOrder(CreateOrderRequest request) {
        return orderRepository.save(new Order(null, request.customerId(),
                OrderStatus.CREATED, request.totalAmount(), null, null, null))
            .flatMap(order -> Flux.fromIterable(request.items())
                .flatMap(item -> orderItemRepository.save(new OrderItem(
                    null, order.id(), item.productId(), item.quantity(), item.unitPrice())))
                .collectList()
                .map(items -> new OrderResponse(order, items)));
    }
}
```

## Connection Pool Configuration

```yaml
spring:
  r2dbc:
    url: r2dbc:postgresql://localhost:5432/orders
    username: ${DB_USERNAME}
    password: ${DB_PASSWORD}
    pool:
      initial-size: 5
      max-size: 20
      max-idle-time: 30m
      validation-query: SELECT 1
```

## Schema Initialization

```yaml
spring:
  sql:
    init:
      mode: always
      schema-locations: classpath:schema.sql
```

```sql
-- schema.sql
CREATE TABLE IF NOT EXISTS orders (
    id BIGSERIAL PRIMARY KEY,
    customer_id VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'CREATED',
    total_amount DECIMAL(12, 2) NOT NULL,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);

CREATE TABLE IF NOT EXISTS order_items (
    id BIGSERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id VARCHAR(255) NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
```

## R2DBC Auditing

```kotlin
@Configuration
@EnableR2dbcAuditing
class R2dbcAuditConfig {

    @Bean
    fun auditorProvider(): ReactiveAuditorAware<String> =
        ReactiveAuditorAware {
            ReactiveSecurityContextHolder.getContext()
                .map { it.authentication.name }
                .defaultIfEmpty("system")
        }
}
```

## Testing Reactive Repositories

### Kotlin

```kotlin
@DataR2dbcTest
@Import(R2dbcAuditConfig::class)
class OrderRepositoryTest {

    @Autowired
    private lateinit var orderRepository: OrderRepository

    @Autowired
    private lateinit var databaseClient: DatabaseClient

    @BeforeEach
    fun setup() = runBlocking {
        databaseClient.sql("DELETE FROM order_items").await()
        databaseClient.sql("DELETE FROM orders").await()
    }

    @Test
    fun `should save and find order`() = runBlocking {
        val order = Order(
            customerId = "cust-1",
            totalAmount = BigDecimal("99.99"),
            status = OrderStatus.CREATED
        )

        val saved = orderRepository.save(order)
        assertNotNull(saved.id)

        val found = orderRepository.findById(saved.id!!)
        assertNotNull(found)
        assertEquals("cust-1", found!!.customerId)
        assertEquals(BigDecimal("99.99"), found.totalAmount)
    }

    @Test
    fun `should find orders by status`() = runBlocking {
        orderRepository.save(Order(customerId = "c1", totalAmount = BigDecimal("10"), status = OrderStatus.CREATED))
        orderRepository.save(Order(customerId = "c2", totalAmount = BigDecimal("20"), status = OrderStatus.CONFIRMED))
        orderRepository.save(Order(customerId = "c3", totalAmount = BigDecimal("30"), status = OrderStatus.CREATED))

        val created = orderRepository.findByStatus(OrderStatus.CREATED).toList()
        assertEquals(2, created.size)
    }
}
```

## Best Practices

1. **Use CoroutineCrudRepository** with Kotlin for cleaner code
2. **Manage relationships manually** — R2DBC has no lazy loading or cascading
3. **Use DatabaseClient** for complex joins and aggregations
4. **Configure connection pooling** — always set max-size and idle-time
5. **Use schema.sql** for DDL — R2DBC does not auto-generate schemas
6. **Prefer immutable entities** — use Kotlin data classes with copy()
7. **Use @Transactional** on service methods, not repository methods
8. **Index foreign keys** — R2DBC does not create them automatically
9. **Test with @DataR2dbcTest** — uses embedded or Testcontainers database
10. **Handle empty results** — `awaitOneOrNull()` in Kotlin, `switchIfEmpty()` in Java
