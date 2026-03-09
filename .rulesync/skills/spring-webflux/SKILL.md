---
name: spring-webflux
description: "Spring WebFlux: reactive REST, WebClient, Router functions, R2DBC integration, SSE"
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Spring WebFlux

Comprehensive guide for reactive web applications with Spring WebFlux: annotated controllers, functional endpoints, WebClient, SSE, and
Kotlin coroutine integration.

## When to Use WebFlux vs Web MVC

| Criteria        | WebFlux                              | Web MVC                      |
|-----------------|--------------------------------------|------------------------------|
| I/O pattern     | Many concurrent I/O-bound requests   | CPU-bound or simple CRUD     |
| Database        | R2DBC, reactive MongoDB              | JPA/Hibernate, JDBC          |
| Team experience | Comfortable with reactive/coroutines | Traditional imperative style |
| Ecosystem       | Reactive libraries available         | Blocking libraries dominant  |
| Streaming       | SSE, WebSockets, backpressure needed | Request-response only        |

## Annotated Controllers with Mono/Flux

### Kotlin (Coroutines — preferred)

```kotlin
@RestController
@RequestMapping("/api/v1/orders")
class OrderController(
    private val orderService: OrderService
) {

    @GetMapping
    fun listOrders(
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "20") size: Int
    ): Flow<OrderResponse> =
        orderService.findAll(page, size)

    @GetMapping("/{id}")
    suspend fun getOrder(@PathVariable id: Long): ResponseEntity<OrderResponse> {
        val order = orderService.findById(id)
        return if (order != null) ResponseEntity.ok(order)
        else ResponseEntity.notFound().build()
    }

    @PostMapping
    suspend fun createOrder(
        @Valid @RequestBody request: CreateOrderRequest
    ): ResponseEntity<OrderResponse> {
        val order = orderService.create(request)
        return ResponseEntity
            .created(URI.create("/api/v1/orders/${order.id}"))
            .body(order)
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    suspend fun deleteOrder(@PathVariable id: Long) {
        orderService.delete(id)
    }
}
```

### Java (Mono/Flux)

```java
@RestController
@RequestMapping("/api/v1/orders")
public class OrderController {

    private final OrderService orderService;

    public OrderController(OrderService orderService) {
        this.orderService = orderService;
    }

    @GetMapping
    public Flux<OrderResponse> listOrders(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return orderService.findAll(page, size);
    }

    @GetMapping("/{id}")
    public Mono<ResponseEntity<OrderResponse>> getOrder(@PathVariable Long id) {
        return orderService.findById(id)
            .map(ResponseEntity::ok)
            .defaultIfEmpty(ResponseEntity.notFound().build());
    }

    @PostMapping
    public Mono<ResponseEntity<OrderResponse>> createOrder(
            @Valid @RequestBody CreateOrderRequest request) {
        return orderService.create(request)
            .map(order -> ResponseEntity
                .created(URI.create("/api/v1/orders/" + order.id()))
                .body(order));
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public Mono<Void> deleteOrder(@PathVariable Long id) {
        return orderService.delete(id);
    }
}
```

## Functional Endpoints (Router Functions)

### Kotlin

```kotlin
@Configuration
class OrderRouter {

    @Bean
    fun orderRoutes(handler: OrderHandler): RouterFunction<ServerResponse> =
        coRouter {
            "/api/v1/orders".nest {
                GET("", handler::listOrders)
                GET("/{id}", handler::getOrder)
                POST("", handler::createOrder)
                DELETE("/{id}", handler::deleteOrder)
            }
        }
}

@Component
class OrderHandler(
    private val orderService: OrderService
) {

    suspend fun listOrders(request: ServerRequest): ServerResponse {
        val page = request.queryParam("page").orElse("0").toInt()
        val size = request.queryParam("size").orElse("20").toInt()
        val orders = orderService.findAll(page, size)
        return ServerResponse.ok()
            .contentType(MediaType.APPLICATION_JSON)
            .bodyAndAwait(orders)
    }

    suspend fun getOrder(request: ServerRequest): ServerResponse {
        val id = request.pathVariable("id").toLong()
        val order = orderService.findById(id)
        return if (order != null) {
            ServerResponse.ok()
                .contentType(MediaType.APPLICATION_JSON)
                .bodyValueAndAwait(order)
        } else {
            ServerResponse.notFound().buildAndAwait()
        }
    }

    suspend fun createOrder(request: ServerRequest): ServerResponse {
        val body = request.awaitBody<CreateOrderRequest>()
        val order = orderService.create(body)
        return ServerResponse.created(URI.create("/api/v1/orders/${order.id}"))
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValueAndAwait(order)
    }

    suspend fun deleteOrder(request: ServerRequest): ServerResponse {
        val id = request.pathVariable("id").toLong()
        orderService.delete(id)
        return ServerResponse.noContent().buildAndAwait()
    }
}
```

### Java

```java
@Configuration
public class OrderRouter {

    @Bean
    public RouterFunction<ServerResponse> orderRoutes(OrderHandler handler) {
        return RouterFunctions.route()
            .path("/api/v1/orders", builder -> builder
                .GET("", handler::listOrders)
                .GET("/{id}", handler::getOrder)
                .POST("", handler::createOrder)
                .DELETE("/{id}", handler::deleteOrder)
            )
            .build();
    }
}

@Component
public class OrderHandler {

    private final OrderService orderService;

    public OrderHandler(OrderService orderService) {
        this.orderService = orderService;
    }

    public Mono<ServerResponse> listOrders(ServerRequest request) {
        int page = Integer.parseInt(request.queryParam("page").orElse("0"));
        int size = Integer.parseInt(request.queryParam("size").orElse("20"));
        return ServerResponse.ok()
            .contentType(MediaType.APPLICATION_JSON)
            .body(orderService.findAll(page, size), OrderResponse.class);
    }

    public Mono<ServerResponse> getOrder(ServerRequest request) {
        Long id = Long.parseLong(request.pathVariable("id"));
        return orderService.findById(id)
            .flatMap(order -> ServerResponse.ok()
                .contentType(MediaType.APPLICATION_JSON)
                .bodyValue(order))
            .switchIfEmpty(ServerResponse.notFound().build());
    }
}
```

## WebClient

### Kotlin (Coroutines)

```kotlin
@Service
class PaymentService(
    private val webClientBuilder: WebClient.Builder
) {
    private val webClient = webClientBuilder
        .baseUrl("https://api.payment.com")
        .defaultHeader(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE)
        .build()

    suspend fun processPayment(request: PaymentRequest): PaymentResponse =
        webClient.post()
            .uri("/v1/charges")
            .bodyValue(request)
            .retrieve()
            .onStatus({ it.is4xxClientError }) { response ->
                response.bodyToMono<String>().map { body ->
                    PaymentException("Payment rejected: $body")
                }
            }
            .awaitBody()

    fun getTransactions(accountId: String): Flow<Transaction> =
        webClient.get()
            .uri("/v1/accounts/{id}/transactions", accountId)
            .retrieve()
            .bodyToFlux<Transaction>()
            .asFlow()
}
```

### Java

```java
@Service
public class PaymentService {

    private final WebClient webClient;

    public PaymentService(WebClient.Builder webClientBuilder) {
        this.webClient = webClientBuilder
            .baseUrl("https://api.payment.com")
            .defaultHeader(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE)
            .build();
    }

    public Mono<PaymentResponse> processPayment(PaymentRequest request) {
        return webClient.post()
            .uri("/v1/charges")
            .bodyValue(request)
            .retrieve()
            .onStatus(HttpStatusCode::is4xxClientError, response ->
                response.bodyToMono(String.class)
                    .map(body -> new PaymentException("Payment rejected: " + body)))
            .bodyToMono(PaymentResponse.class);
    }

    public Flux<Transaction> getTransactions(String accountId) {
        return webClient.get()
            .uri("/v1/accounts/{id}/transactions", accountId)
            .retrieve()
            .bodyToFlux(Transaction.class);
    }
}
```

### WebClient with Retry and Timeout

```kotlin
suspend fun fetchWithResilience(id: String): DataResponse =
    webClient.get()
        .uri("/data/{id}", id)
        .retrieve()
        .bodyToMono<DataResponse>()
        .timeout(Duration.ofSeconds(5))
        .retryWhen(Retry.backoff(3, Duration.ofMillis(500))
            .filter { it is WebClientResponseException.ServiceUnavailable })
        .awaitSingle()
```

## Server-Sent Events (SSE)

### Kotlin

```kotlin
@RestController
@RequestMapping("/api/v1/events")
class EventController(
    private val eventService: EventService
) {

    @GetMapping(produces = [MediaType.TEXT_EVENT_STREAM_VALUE])
    fun streamEvents(): Flow<ServerSentEvent<EventData>> =
        eventService.streamEvents()
            .map { event ->
                ServerSentEvent.builder(event)
                    .id(event.id.toString())
                    .event(event.type)
                    .retry(Duration.ofSeconds(5))
                    .build()
            }
}
```

### Java

```java
@GetMapping(produces = MediaType.TEXT_EVENT_STREAM_VALUE)
public Flux<ServerSentEvent<EventData>> streamEvents() {
    return eventService.streamEvents()
        .map(event -> ServerSentEvent.<EventData>builder(event)
            .id(String.valueOf(event.id()))
            .event(event.type())
            .retry(Duration.ofSeconds(5))
            .build());
}
```

## Reactive Error Handling

### Kotlin

```kotlin
@Service
class OrderService(
    private val orderRepository: OrderRepository,
    private val paymentService: PaymentService
) {

    suspend fun createOrder(request: CreateOrderRequest): OrderResponse {
        val order = orderRepository.save(request.toEntity())
        val payment = try {
            paymentService.processPayment(order.toPaymentRequest())
        } catch (ex: PaymentException) {
            orderRepository.updateStatus(order.id, OrderStatus.PAYMENT_FAILED)
            throw BusinessException("Payment failed for order ${order.id}: ${ex.message}")
        }
        return orderRepository.updateStatus(order.id, OrderStatus.CONFIRMED)
            .toResponse(payment)
    }
}
```

### Java

```java
public Mono<OrderResponse> createOrder(CreateOrderRequest request) {
    return orderRepository.save(request.toEntity())
        .flatMap(order -> paymentService.processPayment(order.toPaymentRequest())
            .map(payment -> order.toResponse(payment))
            .onErrorResume(PaymentException.class, ex ->
                orderRepository.updateStatus(order.id(), OrderStatus.PAYMENT_FAILED)
                    .then(Mono.error(new BusinessException(
                        "Payment failed for order " + order.id() + ": " + ex.getMessage()))))
        );
}
```

## R2DBC Integration

```kotlin
@Service
class OrderService(
    private val orderRepository: OrderRepository
) {
    suspend fun findById(id: Long): Order? =
        orderRepository.findById(id)

    fun findByStatus(status: OrderStatus): Flow<Order> =
        orderRepository.findByStatus(status)
}

interface OrderRepository : CoroutineCrudRepository<Order, Long> {
    fun findByStatus(status: OrderStatus): Flow<Order>

    @Query("SELECT * FROM orders WHERE customer_id = :customerId ORDER BY created_at DESC")
    fun findByCustomerId(customerId: String): Flow<Order>
}
```

## Testing with WebTestClient

### Kotlin

```kotlin
@WebFluxTest(OrderController::class)
class OrderControllerTest {

    @Autowired
    private lateinit var webTestClient: WebTestClient

    @MockkBean
    private lateinit var orderService: OrderService

    @Test
    fun `should return order by id`() {
        val order = OrderResponse(id = 1, status = OrderStatus.ACTIVE)
        coEvery { orderService.findById(1) } returns order

        webTestClient.get()
            .uri("/api/v1/orders/1")
            .exchange()
            .expectStatus().isOk
            .expectBody<OrderResponse>()
            .isEqualTo(order)
    }

    @Test
    fun `should return 404 when order not found`() {
        coEvery { orderService.findById(999) } returns null

        webTestClient.get()
            .uri("/api/v1/orders/999")
            .exchange()
            .expectStatus().isNotFound
    }

    @Test
    fun `should create order`() {
        val request = CreateOrderRequest(customerId = "cust-1", items = listOf())
        val response = OrderResponse(id = 1, status = OrderStatus.CREATED)
        coEvery { orderService.create(request) } returns response

        webTestClient.post()
            .uri("/api/v1/orders")
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(request)
            .exchange()
            .expectStatus().isCreated
            .expectHeader().location("/api/v1/orders/1")
            .expectBody<OrderResponse>()
            .isEqualTo(response)
    }
}
```

## Best Practices

1. **Use Kotlin coroutines** over raw Mono/Flux when using Kotlin
2. **Never block** in a reactive pipeline — no `.block()`, no blocking I/O
3. **Use WebClient** instead of RestTemplate in WebFlux applications
4. **Handle backpressure** — use `.limitRate()`, `.buffer()` when needed
5. **Prefer functional endpoints** for lightweight microservices
6. **Use annotated controllers** when team is more familiar with Spring MVC style
7. **Test with WebTestClient** — supports both mock and live server modes
8. **Configure timeouts** on all WebClient calls
9. **Use R2DBC** for database access — never use JDBC in WebFlux
10. **Handle errors explicitly** — empty Mono is not an error, treat it appropriately
