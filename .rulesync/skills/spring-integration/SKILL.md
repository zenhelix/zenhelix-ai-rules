---
name: spring-integration
description: "Spring Integration: message channels, adapters, transformers, gateways, flows"
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Spring Integration

Comprehensive guide for Spring Integration: messaging concepts, integration DSL, channels, adapters, transformers, gateways, and patterns.

## Core Concepts

- **Message**: Payload + Headers — the unit of data in the integration flow
- **MessageChannel**: Pipe connecting components
- **MessageHandler**: Processes messages (endpoints, adapters, transformers)
- **Gateway**: Entry point to the messaging system from application code
- **Adapter**: Connects to external systems (file, HTTP, JMS, AMQP, etc.)

## Integration DSL: IntegrationFlows

### Kotlin

```kotlin
@Configuration
class OrderIntegrationConfig {

    @Bean
    fun orderProcessingFlow(
        orderService: OrderService,
        notificationService: NotificationService
    ): IntegrationFlow =
        IntegrationFlow.from("orderInputChannel")
            .filter<OrderMessage> { it.totalAmount > BigDecimal.ZERO }
            .transform<OrderMessage, Order> { msg ->
                Order(
                    customerId = msg.customerId,
                    totalAmount = msg.totalAmount,
                    items = msg.items.map { it.toOrderItem() }
                )
            }
            .handle { order: Order, _ ->
                orderService.create(order)
            }
            .channel("orderOutputChannel")
            .get()

    @Bean
    fun notificationFlow(): IntegrationFlow =
        IntegrationFlow.from("orderOutputChannel")
            .transform<Order, NotificationRequest> { order ->
                NotificationRequest(
                    recipient = order.customerId,
                    subject = "Order Confirmation",
                    body = "Your order #${order.id} has been placed"
                )
            }
            .handle { notification: NotificationRequest, _ ->
                notificationService.send(notification)
            }
            .get()
}
```

### Java

```java
@Configuration
public class OrderIntegrationConfig {

    @Bean
    public IntegrationFlow orderProcessingFlow(OrderService orderService) {
        return IntegrationFlow.from("orderInputChannel")
            .filter(OrderMessage.class, msg -> msg.getTotalAmount().compareTo(BigDecimal.ZERO) > 0)
            .transform(OrderMessage.class, msg -> new Order(
                msg.getCustomerId(),
                msg.getTotalAmount(),
                msg.getItems().stream().map(OrderItemMessage::toOrderItem).toList()
            ))
            .handle(Order.class, (order, headers) -> orderService.create(order))
            .channel("orderOutputChannel")
            .get();
    }
}
```

## Channel Types

### Direct Channel (Synchronous, Point-to-Point)

```kotlin
@Bean
fun orderInputChannel(): MessageChannel = DirectChannel()
```

### Queue Channel (Asynchronous, Point-to-Point)

```kotlin
@Bean
fun orderQueueChannel(): MessageChannel =
    QueueChannel(100) // Capacity of 100 messages

@Bean
fun queuePoller(): IntegrationFlow =
    IntegrationFlow.from("orderQueueChannel")
        .bridge { e -> e.poller(Pollers.fixedDelay(1000).maxMessagesPerPoll(10)) }
        .handle { message: Message<*>, _ ->
            processMessage(message)
        }
        .get()
```

### Publish-Subscribe Channel (Fan-Out)

```kotlin
@Bean
fun orderEventChannel(): MessageChannel = PublishSubscribeChannel()

// Multiple subscribers
@Bean
fun auditSubscriber(): IntegrationFlow =
    IntegrationFlow.from("orderEventChannel")
        .handle { order: Order, _ -> auditService.logOrderEvent(order) }
        .get()

@Bean
fun analyticsSubscriber(): IntegrationFlow =
    IntegrationFlow.from("orderEventChannel")
        .handle { order: Order, _ -> analyticsService.trackOrder(order) }
        .get()

@Bean
fun notificationSubscriber(): IntegrationFlow =
    IntegrationFlow.from("orderEventChannel")
        .handle { order: Order, _ -> notificationService.notifyCustomer(order) }
        .get()
```

### Priority Channel

```kotlin
@Bean
fun priorityChannel(): MessageChannel =
    PriorityChannel(100, Comparator.comparing<Message<*>, Int> { msg ->
        msg.headers["priority"] as? Int ?: 0
    }.reversed())
```

## Adapters

### File Adapter

```kotlin
// Reading files from a directory
@Bean
fun fileReadingFlow(): IntegrationFlow =
    IntegrationFlow.from(
        Files.inboundAdapter(File("/data/inbox"))
            .patternFilter("*.csv")
            .preventDuplicates(true)
    ) { e -> e.poller(Pollers.fixedDelay(5000)) }
        .transform(Files.toStringTransformer())
        .channel("fileProcessingChannel")
        .get()

// Writing files to a directory
@Bean
fun fileWritingFlow(): IntegrationFlow =
    IntegrationFlow.from("fileOutputChannel")
        .handle(
            Files.outboundAdapter(File("/data/outbox"))
                .autoCreateDirectory(true)
                .fileNameGenerator { msg ->
                    "order-${msg.headers["orderId"]}-${System.currentTimeMillis()}.csv"
                }
        )
        .get()
```

### HTTP Adapter

```kotlin
// Inbound HTTP gateway
@Bean
fun httpInboundFlow(): IntegrationFlow =
    IntegrationFlow.from(
        Http.inboundGateway("/api/integration/orders")
            .requestMapping { m -> m.methods(HttpMethod.POST) }
            .requestPayloadType(OrderMessage::class.java)
    )
        .channel("orderInputChannel")
        .get()

// Outbound HTTP adapter
@Bean
fun httpOutboundFlow(): IntegrationFlow =
    IntegrationFlow.from("externalApiChannel")
        .handle(
            Http.outboundGateway("https://api.external.com/v1/orders")
                .httpMethod(HttpMethod.POST)
                .expectedResponseType(ExternalOrderResponse::class.java)
                .mappedRequestHeaders("Authorization", "Content-Type")
        )
        .channel("externalApiResponseChannel")
        .get()
```

### JDBC Adapter

```kotlin
@Bean
fun jdbcInboundFlow(dataSource: DataSource): IntegrationFlow =
    IntegrationFlow.from(
        Jdbc.inboundAdapter(dataSource, "SELECT * FROM orders WHERE status = 'PENDING' AND processed = false")
            .updateSql("UPDATE orders SET processed = true WHERE id IN (:id)")
    ) { e -> e.poller(Pollers.fixedDelay(10000)) }
        .split()
        .channel("orderProcessingChannel")
        .get()

@Bean
fun jdbcOutboundFlow(dataSource: DataSource): IntegrationFlow =
    IntegrationFlow.from("persistChannel")
        .handle(
            Jdbc.outboundAdapter(dataSource)
                .sql("INSERT INTO audit_log (order_id, event_type, timestamp) VALUES (:payload.orderId, :payload.eventType, :payload.timestamp)")
        )
        .get()
```

### AMQP Adapter (RabbitMQ)

```kotlin
@Bean
fun amqpInboundFlow(connectionFactory: ConnectionFactory): IntegrationFlow =
    IntegrationFlow.from(
        Amqp.inboundAdapter(connectionFactory, "order.queue")
            .configureContainer { c ->
                c.concurrentConsumers(3)
                c.prefetchCount(10)
            }
    )
        .transform(Transformers.fromJson(OrderEvent::class.java))
        .channel("orderEventChannel")
        .get()

@Bean
fun amqpOutboundFlow(amqpTemplate: AmqpTemplate): IntegrationFlow =
    IntegrationFlow.from("notificationChannel")
        .transform(Transformers.toJson())
        .handle(
            Amqp.outboundAdapter(amqpTemplate)
                .exchangeName("notifications")
                .routingKey("notification.email")
        )
        .get()
```

### TCP Adapter

```kotlin
@Bean
fun tcpServerFlow(): IntegrationFlow {
    val serverFactory = TcpNetServerConnectionFactory(9090).apply {
        serializer = ByteArrayLfSerializer()
        deserializer = ByteArrayLfSerializer()
    }

    return IntegrationFlow.from(Tcp.inboundAdapter(serverFactory))
        .transform<ByteArray, String> { String(it) }
        .handle { payload: String, _ ->
            processCommand(payload)
        }
        .get()
}
```

## Transformers and Filters

```kotlin
@Bean
fun transformationFlow(): IntegrationFlow =
    IntegrationFlow.from("rawInputChannel")
        // Filter
        .filter<RawMessage> { msg ->
            msg.type == "ORDER" && msg.payload.isNotBlank()
        }
        // Transform with JSON
        .transform(Transformers.fromJson(OrderPayload::class.java))
        // Enrich headers
        .enrichHeaders { h ->
            h.header("processedAt", Instant.now())
            h.headerExpression("priority", "payload.totalAmount > 1000 ? 'HIGH' : 'NORMAL'")
        }
        // Custom transformation
        .transform<OrderPayload, ProcessedOrder> { payload ->
            ProcessedOrder(
                orderId = payload.orderId,
                normalizedAmount = payload.amount.setScale(2, RoundingMode.HALF_UP),
                region = resolveRegion(payload.zipCode)
            )
        }
        .channel("processedOrderChannel")
        .get()
```

## Service Activator

```kotlin
@Bean
fun serviceActivatorFlow(): IntegrationFlow =
    IntegrationFlow.from("serviceChannel")
        .handle(OrderService::class.java, "processOrder")
        .get()

// Or with explicit service activator
@ServiceActivator(inputChannel = "orderChannel")
fun handleOrder(order: Order): OrderResult =
    orderService.processOrder(order)
```

## Gateway Interface

### Kotlin

```kotlin
@MessagingGateway
interface OrderGateway {

    @Gateway(requestChannel = "orderInputChannel", replyChannel = "orderOutputChannel")
    fun submitOrder(order: OrderMessage): Order

    @Gateway(requestChannel = "orderInputChannel")
    fun submitOrderAsync(order: OrderMessage): Future<Order>

    @Gateway(requestChannel = "batchOrderChannel")
    fun submitBatch(orders: List<OrderMessage>)
}

// Usage in controller
@RestController
@RequestMapping("/api/v1/orders")
class OrderController(
    private val orderGateway: OrderGateway
) {

    @PostMapping
    fun createOrder(@Valid @RequestBody request: CreateOrderRequest): ResponseEntity<Order> {
        val orderMessage = request.toMessage()
        val order = orderGateway.submitOrder(orderMessage)
        return ResponseEntity.created(URI.create("/api/v1/orders/${order.id}")).body(order)
    }
}
```

### Java

```java
@MessagingGateway
public interface OrderGateway {

    @Gateway(requestChannel = "orderInputChannel", replyChannel = "orderOutputChannel")
    Order submitOrder(OrderMessage order);

    @Gateway(requestChannel = "orderInputChannel")
    Future<Order> submitOrderAsync(OrderMessage order);
}
```

## Splitter/Aggregator Patterns

### Kotlin

```kotlin
@Bean
fun splitAggregateFlow(): IntegrationFlow =
    IntegrationFlow.from("batchOrderChannel")
        // Split batch into individual orders
        .split()
        // Process each order
        .channel { c -> c.executor(taskExecutor()) } // Parallel processing
        .handle { order: OrderMessage, _ ->
            orderService.process(order)
        }
        // Aggregate results
        .aggregate { a ->
            a.correlationStrategy { msg ->
                msg.headers["correlationId"]
            }
            a.releaseStrategy { group ->
                group.size() == group.sequenceSize
            }
            a.outputProcessor { group ->
                BatchResult(
                    total = group.size(),
                    successful = group.messages.count { (it.payload as OrderResult).success },
                    results = group.messages.map { it.payload as OrderResult }
                )
            }
            a.groupTimeout(30000) // Timeout after 30 seconds
            a.sendPartialResultOnExpiry(true)
        }
        .channel("batchResultChannel")
        .get()
```

## Error Handling

### Error Channel

```kotlin
@Bean
fun errorHandlingFlow(): IntegrationFlow =
    IntegrationFlow.from("errorChannel")
        .handle { message: ErrorMessage, _ ->
            val cause = message.payload
            logger.error("Integration error: ${cause.message}", cause)

            when (cause) {
                is MessageHandlingException -> {
                    val failedMessage = cause.failedMessage
                    deadLetterService.store(failedMessage, cause)
                }
                is MessageDeliveryException -> {
                    alertService.sendAlert("Channel delivery failed: ${cause.message}")
                }
                else -> {
                    alertService.sendAlert("Unknown integration error: ${cause.message}")
                }
            }
            null
        }
        .get()

// Per-flow error channel
@Bean
fun orderFlowWithErrorHandling(): IntegrationFlow =
    IntegrationFlow.from("orderInputChannel")
        .handle({ order: Order, _ ->
            orderService.process(order)
        }) { e ->
            e.advice(retryAdvice())
        }
        .get()

@Bean
fun retryAdvice(): RequestHandlerRetryAdvice =
    RequestHandlerRetryAdvice().apply {
        setRetryTemplate(RetryTemplate().apply {
            setRetryPolicy(SimpleRetryPolicy(3))
            setBackOffPolicy(ExponentialBackOffPolicy().apply {
                initialInterval = 1000
                multiplier = 2.0
                maxInterval = 10000
            })
        })
        setRecoveryCallback { context ->
            val failedMessage = (context.lastThrowable as MessagingException).failedMessage
            logger.error("Retry exhausted for message: $failedMessage")
            deadLetterService.store(failedMessage)
            null
        }
    }
```

## Poller Configuration

```kotlin
@Bean
fun pollerMetadata(): PollerMetadata =
    PollerMetadata().apply {
        trigger = PeriodicTrigger(Duration.ofSeconds(5))
        maxMessagesPerPoll = 10
        taskExecutor = taskExecutor()
        errorHandler = MessagePublishingErrorHandler().apply {
            defaultErrorChannel = errorChannel()
        }
    }

@Bean
fun taskExecutor(): TaskExecutor =
    ThreadPoolTaskExecutor().apply {
        corePoolSize = 5
        maxPoolSize = 10
        queueCapacity = 25
        setThreadNamePrefix("integration-")
    }
```

## Testing with MockIntegrationContext

### Kotlin

```kotlin
@SpringIntegrationTest
@SpringBootTest
class OrderIntegrationFlowTest {

    @Autowired
    private lateinit var mockIntegrationContext: MockIntegrationContext

    @Autowired
    @Qualifier("orderInputChannel")
    private lateinit var inputChannel: MessageChannel

    @Autowired
    @Qualifier("orderOutputChannel")
    private lateinit var outputChannel: QueueChannel

    @Test
    fun `should process valid order through flow`() {
        val orderMessage = OrderMessage(
            customerId = "cust-1",
            totalAmount = BigDecimal("100.00"),
            items = listOf(OrderItemMessage("prod-1", 2, BigDecimal("50.00")))
        )

        inputChannel.send(MessageBuilder.withPayload(orderMessage).build())

        val result = outputChannel.receive(5000)
        assertNotNull(result)
        val order = result!!.payload as Order
        assertEquals("cust-1", order.customerId)
    }

    @Test
    fun `should filter out zero amount orders`() {
        val orderMessage = OrderMessage(
            customerId = "cust-1",
            totalAmount = BigDecimal.ZERO,
            items = emptyList()
        )

        inputChannel.send(MessageBuilder.withPayload(orderMessage).build())

        val result = outputChannel.receive(2000)
        assertNull(result) // Filtered out
    }

    @Test
    fun `should mock external adapter`() {
        mockIntegrationContext.substituteMessageHandlerFor(
            "externalServiceHandler",
            MockMessageHandler.builder()
                .handleNextAndReply<Any> { ExternalResponse(status = "OK") }
                .build()
        )

        inputChannel.send(MessageBuilder.withPayload(testPayload).build())

        val result = outputChannel.receive(5000)
        assertNotNull(result)
    }
}
```

## Best Practices

1. **Use the DSL** over XML or annotation-based configuration
2. **Name your channels** explicitly for clarity and debugging
3. **Use error channels** — configure per-flow and global error handling
4. **Configure pollers** — set appropriate delays and batch sizes
5. **Use thread pools** — configure task executors for concurrent processing
6. **Use gateways** as the entry point from application code into flows
7. **Idempotent receivers** — use `IdempotentReceiverInterceptor` for at-least-once delivery
8. **Monitor channels** — use `MessageChannelMetrics` for observability
9. **Use message store** — persist messages for reliability (JDBC, MongoDB)
10. **Test with MockIntegrationContext** — substitute handlers for isolated testing
