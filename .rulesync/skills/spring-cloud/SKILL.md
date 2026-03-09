---
name: spring-cloud
description: "Spring Cloud: Config Server, Gateway, Circuit breaker, Service discovery, Feign"
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Spring Cloud

Comprehensive guide for Spring Cloud: Config Server, Gateway, Circuit Breaker, Service Discovery, Feign, and distributed tracing.

## Spring Cloud Config

### Config Server Setup

```kotlin
@SpringBootApplication
@EnableConfigServer
class ConfigServerApplication

fun main(args: Array<String>) {
    runApplication<ConfigServerApplication>(*args)
}
```

```yaml
# Config Server application.yml
server:
  port: 8888

spring:
  cloud:
    config:
      server:
        git:
          uri: https://github.com/org/config-repo
          default-label: main
          search-paths: "{application}"
          clone-on-start: true
        # Or native filesystem
        # native:
        #   search-locations: classpath:/config
```

### Config Client

```yaml
# Client application.yml
spring:
  application:
    name: order-service
  config:
    import: configserver:http://localhost:8888
  cloud:
    config:
      fail-fast: true
      retry:
        max-attempts: 5
        initial-interval: 1000
```

### Refresh Configuration at Runtime

```kotlin
@RefreshScope
@Service
class FeatureFlagService(
    @Value("\${app.feature.new-checkout:false}") private val newCheckoutEnabled: Boolean
) {
    fun isNewCheckoutEnabled(): Boolean = newCheckoutEnabled
}
```

Trigger refresh via actuator: `POST /actuator/refresh`

For bus-based refresh across instances:

```yaml
spring:
  cloud:
    bus:
      enabled: true
  rabbitmq:
    host: localhost
    port: 5672
```

Trigger: `POST /actuator/busrefresh`

## Spring Cloud Gateway

### Route Configuration

#### Kotlin

```kotlin
@Configuration
class GatewayConfig {

    @Bean
    fun routes(builder: RouteLocatorBuilder): RouteLocator =
        builder.routes()
            .route("order-service") { r ->
                r.path("/api/v1/orders/**")
                    .filters { f ->
                        f.stripPrefix(0)
                            .addRequestHeader("X-Gateway", "true")
                            .circuitBreaker { cb ->
                                cb.setName("orderServiceCB")
                                cb.setFallbackUri("forward:/fallback/orders")
                            }
                            .retry { retry ->
                                retry.retries = 3
                                retry.setStatuses(HttpStatus.SERVICE_UNAVAILABLE)
                            }
                    }
                    .uri("lb://order-service")
            }
            .route("user-service") { r ->
                r.path("/api/v1/users/**")
                    .filters { f ->
                        f.stripPrefix(0)
                            .requestRateLimiter { rl ->
                                rl.rateLimiter = redisRateLimiter()
                            }
                    }
                    .uri("lb://user-service")
            }
            .build()

    @Bean
    fun redisRateLimiter(): RedisRateLimiter =
        RedisRateLimiter(10, 20) // 10 requests/sec, burst of 20
}
```

#### YAML Configuration

```yaml
spring:
  cloud:
    gateway:
      routes:
        - id: order-service
          uri: lb://order-service
          predicates:
            - Path=/api/v1/orders/**
          filters:
            - AddRequestHeader=X-Gateway, true
            - name: CircuitBreaker
              args:
                name: orderServiceCB
                fallbackUri: forward:/fallback/orders
            - name: Retry
              args:
                retries: 3
                statuses: SERVICE_UNAVAILABLE

      default-filters:
        - name: RequestRateLimiter
          args:
            redis-rate-limiter.replenishRate: 10
            redis-rate-limiter.burstCapacity: 20
```

### Custom Gateway Filter

```kotlin
@Component
class AuthGatewayFilterFactory : AbstractGatewayFilterFactory<AuthGatewayFilterFactory.Config>(Config::class.java) {

    override fun apply(config: Config): GatewayFilter =
        GatewayFilter { exchange, chain ->
            val token = exchange.request.headers.getFirst(HttpHeaders.AUTHORIZATION)
            if (token == null || !token.startsWith("Bearer ")) {
                exchange.response.statusCode = HttpStatus.UNAUTHORIZED
                return@GatewayFilter exchange.response.setComplete()
            }
            chain.filter(exchange)
        }

    class Config
}
```

### Global Filters

```kotlin
@Component
class LoggingGlobalFilter : GlobalFilter, Ordered {

    private val logger = LoggerFactory.getLogger(javaClass)

    override fun filter(exchange: ServerWebExchange, chain: GatewayFilterChain): Mono<Void> {
        val request = exchange.request
        val requestId = UUID.randomUUID().toString()
        logger.info("Gateway request: {} {} [{}]", request.method, request.uri.path, requestId)

        val mutatedExchange = exchange.mutate()
            .request(exchange.request.mutate().header("X-Request-Id", requestId).build())
            .build()

        val startTime = System.currentTimeMillis()
        return chain.filter(mutatedExchange).then(Mono.fromRunnable {
            val duration = System.currentTimeMillis() - startTime
            logger.info("Gateway response: {} {} [{}] in {}ms",
                request.method, request.uri.path, requestId, duration)
        })
    }

    override fun getOrder(): Int = -1
}
```

## Circuit Breaker with Resilience4j

### Dependencies

```kotlin
implementation("org.springframework.cloud:spring-cloud-starter-circuitbreaker-resilience4j")
```

### Kotlin

```kotlin
@Service
class PaymentService(
    private val paymentClient: PaymentClient
) {

    @CircuitBreaker(name = "paymentService", fallbackMethod = "paymentFallback")
    @Retry(name = "paymentService")
    @TimeLimiter(name = "paymentService")
    suspend fun processPayment(request: PaymentRequest): PaymentResponse =
        paymentClient.charge(request)

    private suspend fun paymentFallback(
        request: PaymentRequest,
        ex: Exception
    ): PaymentResponse {
        logger.warn("Payment circuit breaker fallback for order ${request.orderId}: ${ex.message}")
        return PaymentResponse(
            status = PaymentStatus.PENDING,
            message = "Payment processing delayed, will retry"
        )
    }

    companion object {
        private val logger = LoggerFactory.getLogger(PaymentService::class.java)
    }
}
```

### Java

```java
@Service
public class PaymentService {

    private final PaymentClient paymentClient;

    @CircuitBreaker(name = "paymentService", fallbackMethod = "paymentFallback")
    @Retry(name = "paymentService")
    public PaymentResponse processPayment(PaymentRequest request) {
        return paymentClient.charge(request);
    }

    private PaymentResponse paymentFallback(PaymentRequest request, Exception ex) {
        return new PaymentResponse(PaymentStatus.PENDING, "Payment processing delayed");
    }
}
```

### Configuration

```yaml
resilience4j:
  circuitbreaker:
    instances:
      paymentService:
        slidingWindowSize: 10
        failureRateThreshold: 50
        waitDurationInOpenState: 30s
        permittedNumberOfCallsInHalfOpenState: 3
        registerHealthIndicator: true

  retry:
    instances:
      paymentService:
        maxAttempts: 3
        waitDuration: 1s
        enableExponentialBackoff: true
        exponentialBackoffMultiplier: 2

  timelimiter:
    instances:
      paymentService:
        timeoutDuration: 5s
```

## Service Discovery

### Eureka Server

```kotlin
@SpringBootApplication
@EnableEurekaServer
class EurekaServerApplication

fun main(args: Array<String>) {
    runApplication<EurekaServerApplication>(*args)
}
```

```yaml
# Eureka Server
server:
  port: 8761

eureka:
  client:
    register-with-eureka: false
    fetch-registry: false
```

### Eureka Client

```yaml
# Service application.yml
spring:
  application:
    name: order-service

eureka:
  client:
    service-url:
      defaultZone: http://localhost:8761/eureka/
  instance:
    prefer-ip-address: true
    lease-renewal-interval-in-seconds: 10
    lease-expiration-duration-in-seconds: 30
```

## OpenFeign Declarative HTTP Clients

### Kotlin

```kotlin
@FeignClient(
    name = "payment-service",
    fallbackFactory = PaymentClientFallbackFactory::class,
    configuration = [PaymentClientConfig::class]
)
interface PaymentClient {

    @PostMapping("/api/v1/payments")
    fun charge(@RequestBody request: PaymentRequest): PaymentResponse

    @GetMapping("/api/v1/payments/{id}")
    fun getPayment(@PathVariable id: String): PaymentResponse

    @GetMapping("/api/v1/payments")
    fun listPayments(
        @RequestParam("customerId") customerId: String,
        @RequestParam("page") page: Int,
        @RequestParam("size") size: Int
    ): Page<PaymentResponse>
}

@Component
class PaymentClientFallbackFactory : FallbackFactory<PaymentClient> {

    private val logger = LoggerFactory.getLogger(javaClass)

    override fun create(cause: Throwable): PaymentClient =
        object : PaymentClient {
            override fun charge(request: PaymentRequest): PaymentResponse {
                logger.error("Fallback for charge: ${cause.message}")
                return PaymentResponse(status = PaymentStatus.PENDING, message = "Service unavailable")
            }

            override fun getPayment(id: String): PaymentResponse {
                throw ServiceUnavailableException("Payment service unavailable")
            }

            override fun listPayments(customerId: String, page: Int, size: Int): Page<PaymentResponse> =
                Page.empty()
        }
}

@Configuration
class PaymentClientConfig {

    @Bean
    fun feignRequestInterceptor(): RequestInterceptor =
        RequestInterceptor { template ->
            val auth = SecurityContextHolder.getContext().authentication
            if (auth != null) {
                template.header(HttpHeaders.AUTHORIZATION, "Bearer ${(auth.credentials as? String)}")
            }
        }
}
```

### Java

```java
@FeignClient(
    name = "payment-service",
    fallbackFactory = PaymentClientFallbackFactory.class
)
public interface PaymentClient {

    @PostMapping("/api/v1/payments")
    PaymentResponse charge(@RequestBody PaymentRequest request);

    @GetMapping("/api/v1/payments/{id}")
    PaymentResponse getPayment(@PathVariable String id);
}
```

### Feign Configuration

```yaml
spring:
  cloud:
    openfeign:
      client:
        config:
          default:
            connect-timeout: 5000
            read-timeout: 10000
            logger-level: basic
          payment-service:
            connect-timeout: 3000
            read-timeout: 5000
```

## Load Balancing

```kotlin
@Configuration
class LoadBalancerConfig {

    @Bean
    fun webClientLoadBalanced(builder: WebClient.Builder): WebClient =
        builder
            .filter(loadBalancerExchangeFilterFunction())
            .build()

    @Bean
    @LoadBalanced
    fun restTemplate(): RestTemplate = RestTemplate()
}
```

## Distributed Tracing with Micrometer

```yaml
management:
  tracing:
    sampling:
      probability: 1.0
  zipkin:
    tracing:
      endpoint: http://localhost:9411/api/v2/spans

logging:
  pattern:
    level: "%5p [${spring.application.name},%X{traceId:-},%X{spanId:-}]"
```

```kotlin
implementation("io.micrometer:micrometer-tracing-bridge-otel")
implementation("io.opentelemetry:opentelemetry-exporter-zipkin")
```

## Spring Cloud Stream

### Kotlin

```kotlin
@Configuration
class StreamConfig {

    @Bean
    fun orderCreatedConsumer(): Consumer<OrderCreatedEvent> = Consumer { event ->
        logger.info("Received order created event: ${event.orderId}")
        // Process event
    }

    @Bean
    fun orderStatusSupplier(orderEventService: OrderEventService): Supplier<Flux<OrderStatusEvent>> =
        Supplier { orderEventService.getStatusEvents() }

    @Bean
    fun orderTransformer(): Function<OrderCreatedEvent, NotificationEvent> = Function { event ->
        NotificationEvent(
            recipient = event.customerId,
            message = "Order ${event.orderId} has been created",
            type = NotificationType.EMAIL
        )
    }
}
```

```yaml
spring:
  cloud:
    stream:
      bindings:
        orderCreatedConsumer-in-0:
          destination: order-created
          group: notification-service
        orderStatusSupplier-out-0:
          destination: order-status
      kafka:
        binder:
          brokers: localhost:9092
```

## Health Checks and Readiness Probes

```yaml
management:
  endpoint:
    health:
      probes:
        enabled: true
      show-details: when-authorized
      group:
        readiness:
          include: db,diskSpace,discoveryComposite
        liveness:
          include: ping

# Kubernetes probes
# livenessProbe: /actuator/health/liveness
# readinessProbe: /actuator/health/readiness
```

## Best Practices

1. **Externalize configuration** — use Config Server for centralized management
2. **Circuit breakers on all external calls** — prevent cascade failures
3. **Configure timeouts everywhere** — Feign, WebClient, circuit breaker, gateway
4. **Use service discovery** — avoid hardcoded URLs
5. **Propagate trace IDs** — enable distributed tracing across all services
6. **Use gateway for cross-cutting concerns** — rate limiting, auth, logging
7. **Design for failure** — implement fallbacks for all circuit breakers
8. **Use Spring Cloud Stream** for async communication between services
9. **Health checks per dependency** — separate liveness from readiness probes
10. **Test with WireMock** — mock external services in integration tests
11. **Configuration refresh** — use bus refresh for coordinated config updates
12. **Load balancing** — use Spring Cloud LoadBalancer (Ribbon is deprecated)
