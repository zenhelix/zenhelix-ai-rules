---
name: spring-core
description: "Spring Core: dependency injection, configuration, profiles, properties, actuator, auto-configuration"
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Spring Core

Comprehensive guide for Spring Framework core concepts: dependency injection, configuration, profiles, properties, actuator, and
auto-configuration.

## Stereotype Annotations

Use stereotype annotations to mark classes for component scanning. Each conveys intent about the layer the class belongs to.

### Kotlin

```kotlin
@Component
class EmailValidator

@Service
class OrderService(
    private val orderRepository: OrderRepository,
    private val paymentGateway: PaymentGateway
)

@Repository
class JpaOrderRepository(
    private val entityManager: EntityManager
) : OrderRepository

@Controller
class OrderController(
    private val orderService: OrderService
)
```

### Java

```java
@Component
public class EmailValidator { }

@Service
public class OrderService {
    private final OrderRepository orderRepository;
    private final PaymentGateway paymentGateway;

    public OrderService(OrderRepository orderRepository, PaymentGateway paymentGateway) {
        this.orderRepository = orderRepository;
        this.paymentGateway = paymentGateway;
    }
}

@Repository
public class JpaOrderRepository implements OrderRepository {
    private final EntityManager entityManager;

    public JpaOrderRepository(EntityManager entityManager) {
        this.entityManager = entityManager;
    }
}
```

## Dependency Injection

**Always prefer constructor injection.** It makes dependencies explicit, enables immutability, and simplifies testing.

### Kotlin

```kotlin
// PREFERRED: Constructor injection (automatic for single constructor)
@Service
class UserService(
    private val userRepository: UserRepository,
    private val passwordEncoder: PasswordEncoder
) {
    fun findById(id: Long): User? = userRepository.findById(id).orElse(null)
}

// Using @Qualifier when multiple implementations exist
@Service
class NotificationService(
    @Qualifier("email") private val emailSender: MessageSender,
    @Qualifier("sms") private val smsSender: MessageSender
)
```

### Java

```java
// PREFERRED: Constructor injection
@Service
public class UserService {
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    public UserService(UserRepository userRepository, PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
    }
}

// Using @Qualifier
@Service
public class NotificationService {
    private final MessageSender emailSender;
    private final MessageSender smsSender;

    public NotificationService(
            @Qualifier("email") MessageSender emailSender,
            @Qualifier("sms") MessageSender smsSender) {
        this.emailSender = emailSender;
        this.smsSender = smsSender;
    }
}
```

### Anti-patterns to Avoid

```kotlin
// BAD: Field injection — hides dependencies, untestable without reflection
@Service
class BadService {
    @Autowired
    private lateinit var repository: UserRepository
}

// BAD: Setter injection — allows partially constructed objects
@Service
class AlsoBadService {
    private var repository: UserRepository? = null

    @Autowired
    fun setRepository(repository: UserRepository) {
        this.repository = repository
    }
}
```

## Configuration Classes

### Kotlin

```kotlin
@Configuration
class AppConfig {

    @Bean
    fun objectMapper(): ObjectMapper =
        ObjectMapper()
            .registerKotlinModule()
            .registerModule(JavaTimeModule())
            .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS)

    @Bean
    fun restTemplate(builder: RestTemplateBuilder): RestTemplate =
        builder
            .connectTimeout(Duration.ofSeconds(5))
            .readTimeout(Duration.ofSeconds(10))
            .build()

    @Bean
    @ConditionalOnMissingBean
    fun passwordEncoder(): PasswordEncoder = BCryptPasswordEncoder(12)
}
```

### Java

```java
@Configuration
public class AppConfig {

    @Bean
    public ObjectMapper objectMapper() {
        return new ObjectMapper()
            .registerModule(new JavaTimeModule())
            .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
    }

    @Bean
    public RestTemplate restTemplate(RestTemplateBuilder builder) {
        return builder
            .connectTimeout(Duration.ofSeconds(5))
            .readTimeout(Duration.ofSeconds(10))
            .build();
    }

    @Bean
    @ConditionalOnMissingBean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder(12);
    }
}
```

## Properties and Configuration Binding

### application.yml Structure

```yaml
server:
  port: 8080
  shutdown: graceful

spring:
  application:
    name: order-service
  datasource:
    url: jdbc:postgresql://localhost:5432/orders
    username: ${DB_USERNAME}
    password: ${DB_PASSWORD}
    hikari:
      maximum-pool-size: 20
      minimum-idle: 5

app:
  payment:
    gateway-url: https://api.payment.com
    timeout: 5s
    retry-attempts: 3
  notification:
    enabled: true
    from-email: noreply@example.com
```

### Type-Safe Configuration Properties

#### Kotlin

```kotlin
@ConfigurationProperties(prefix = "app.payment")
data class PaymentProperties(
    val gatewayUrl: String,
    val timeout: Duration = Duration.ofSeconds(5),
    val retryAttempts: Int = 3
)

@ConfigurationProperties(prefix = "app.notification")
data class NotificationProperties(
    val enabled: Boolean = true,
    val fromEmail: String
)

// Enable in main class or config
@SpringBootApplication
@ConfigurationPropertiesScan
class Application
```

#### Java

```java
@ConfigurationProperties(prefix = "app.payment")
public record PaymentProperties(
    String gatewayUrl,
    @DefaultValue("5s") Duration timeout,
    @DefaultValue("3") int retryAttempts
) {}

@ConfigurationProperties(prefix = "app.notification")
public record NotificationProperties(
    @DefaultValue("true") boolean enabled,
    String fromEmail
) {}
```

### @Value for Simple Cases

```kotlin
@Service
class FeatureFlagService(
    @Value("\${app.feature.new-checkout:false}") private val newCheckoutEnabled: Boolean
)
```

**Prefer @ConfigurationProperties over @Value** for anything beyond a single simple property.

## Profiles

### Kotlin

```kotlin
@Configuration
@Profile("local")
class LocalConfig {
    @Bean
    fun dataSource(): DataSource =
        EmbeddedDatabaseBuilder()
            .setType(EmbeddedDatabaseType.H2)
            .build()
}

@Configuration
@Profile("production")
class ProductionConfig {
    @Bean
    fun dataSource(props: DataSourceProperties): DataSource =
        HikariDataSource(HikariConfig().apply {
            jdbcUrl = props.url
            username = props.username
            password = props.password
            maximumPoolSize = 20
        })
}

// Profile-specific beans
@Service
@Profile("!test")
class RealPaymentGateway : PaymentGateway

@Service
@Profile("test")
class MockPaymentGateway : PaymentGateway
```

### Profile-Specific YAML

```yaml
# application-local.yml
spring:
  datasource:
    url: jdbc:h2:mem:testdb
logging:
  level:
    root: DEBUG

# application-production.yml
spring:
  datasource:
    url: jdbc:postgresql://${DB_HOST}:5432/orders
logging:
  level:
    root: WARN
```

Activate profiles via: `SPRING_PROFILES_ACTIVE=production` or `--spring.profiles.active=production`.

## Spring Boot Actuator

### Dependencies

```kotlin
// build.gradle.kts
implementation("org.springframework.boot:spring-boot-starter-actuator")
```

### Configuration

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
  endpoint:
    health:
      show-details: when-authorized
      probes:
        enabled: true
  info:
    env:
      enabled: true
  metrics:
    tags:
      application: ${spring.application.name}
```

### Custom Health Indicator

#### Kotlin

```kotlin
@Component
class PaymentGatewayHealthIndicator(
    private val paymentClient: PaymentClient
) : HealthIndicator {

    override fun health(): Health =
        try {
            paymentClient.ping()
            Health.up()
                .withDetail("gateway", "reachable")
                .build()
        } catch (ex: Exception) {
            Health.down()
                .withDetail("gateway", "unreachable")
                .withException(ex)
                .build()
        }
}
```

#### Java

```java
@Component
public class PaymentGatewayHealthIndicator implements HealthIndicator {

    private final PaymentClient paymentClient;

    public PaymentGatewayHealthIndicator(PaymentClient paymentClient) {
        this.paymentClient = paymentClient;
    }

    @Override
    public Health health() {
        try {
            paymentClient.ping();
            return Health.up()
                .withDetail("gateway", "reachable")
                .build();
        } catch (Exception ex) {
            return Health.down()
                .withDetail("gateway", "unreachable")
                .withException(ex)
                .build();
        }
    }
}
```

### Custom Metrics

```kotlin
@Service
class OrderService(
    private val meterRegistry: MeterRegistry,
    private val orderRepository: OrderRepository
) {
    private val orderCounter = Counter.builder("orders.created")
        .description("Number of orders created")
        .register(meterRegistry)

    fun createOrder(request: CreateOrderRequest): Order {
        val order = orderRepository.save(request.toEntity())
        orderCounter.increment()
        return order
    }
}
```

## Auto-Configuration

### Custom Auto-Configuration

#### Kotlin

```kotlin
@AutoConfiguration
@ConditionalOnClass(PaymentClient::class)
@EnableConfigurationProperties(PaymentProperties::class)
class PaymentAutoConfiguration {

    @Bean
    @ConditionalOnMissingBean
    fun paymentClient(properties: PaymentProperties): PaymentClient =
        DefaultPaymentClient(
            baseUrl = properties.gatewayUrl,
            timeout = properties.timeout
        )

    @Bean
    @ConditionalOnProperty(prefix = "app.payment", name = ["retry-enabled"], havingValue = "true")
    fun retryablePaymentClient(
        delegate: PaymentClient,
        properties: PaymentProperties
    ): PaymentClient =
        RetryablePaymentClient(delegate, properties.retryAttempts)
}
```

#### Java

```java
@AutoConfiguration
@ConditionalOnClass(PaymentClient.class)
@EnableConfigurationProperties(PaymentProperties.class)
public class PaymentAutoConfiguration {

    @Bean
    @ConditionalOnMissingBean
    public PaymentClient paymentClient(PaymentProperties properties) {
        return new DefaultPaymentClient(
            properties.gatewayUrl(),
            properties.timeout()
        );
    }

    @Bean
    @ConditionalOnProperty(prefix = "app.payment", name = "retry-enabled", havingValue = "true")
    public PaymentClient retryablePaymentClient(
            PaymentClient delegate,
            PaymentProperties properties) {
        return new RetryablePaymentClient(delegate, properties.retryAttempts());
    }
}
```

### Registration

Register auto-configuration in `META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports`:

```
com.example.payment.PaymentAutoConfiguration
```

### Common Conditional Annotations

| Annotation                     | Purpose                                        |
|--------------------------------|------------------------------------------------|
| `@ConditionalOnClass`          | Bean exists only if class is on classpath      |
| `@ConditionalOnMissingBean`    | Bean exists only if no other bean of same type |
| `@ConditionalOnProperty`       | Bean exists only if property matches value     |
| `@ConditionalOnMissingClass`   | Bean exists only if class is NOT on classpath  |
| `@ConditionalOnWebApplication` | Bean exists only in web application context    |
| `@ConditionalOnExpression`     | Bean exists based on SpEL expression           |

## Best Practices

1. **Constructor injection only** — never field or setter injection
2. **Use @ConfigurationProperties** over @Value for structured config
3. **Keep @Configuration classes focused** — one concern per class
4. **Use profiles sparingly** — prefer feature flags for runtime toggles
5. **Externalize all secrets** — use environment variables or vault
6. **Enable actuator selectively** — expose only needed endpoints in production
7. **Validate configuration** — use `@Validated` on @ConfigurationProperties
8. **Use immutable config** — Kotlin data classes or Java records for properties
