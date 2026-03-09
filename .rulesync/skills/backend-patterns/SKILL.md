---
name: backend-patterns
description: "Backend architecture: layered design, caching, error handling, retry, rate limiting, logging"
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Backend Architecture Patterns

## Layered Architecture

```
Controller (HTTP layer)
    ↓ DTO / Request objects
Service (Business logic)
    ↓ Domain entities
Repository (Data access)
    ↓ SQL / JPA
Database
```

Rules:

- Controllers handle HTTP concerns only (request parsing, response formatting, status codes)
- Services contain business logic, transaction boundaries, orchestration
- Repositories handle data access only
- No upward dependencies (Repository must not know about Controller)
- Use DTOs between layers to avoid leaking internal representations

## RESTful API Structure

```kotlin
@RestController
@RequestMapping("/api/v1/users")
class UserController(private val userService: UserService) {

    @GetMapping
    fun findAll(
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "20") size: Int,
    ): Page<UserResponse> =
        userService.findAll(PageRequest.of(page, size)).map(User::toResponse)

    @GetMapping("/{id}")
    fun findById(@PathVariable id: Long): UserResponse =
        userService.findById(id).toResponse()

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    fun create(@Valid @RequestBody request: CreateUserRequest): UserResponse =
        userService.create(request).toResponse()

    @PutMapping("/{id}")
    fun update(
        @PathVariable id: Long,
        @Valid @RequestBody request: UpdateUserRequest,
    ): UserResponse =
        userService.update(id, request).toResponse()

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    fun delete(@PathVariable id: Long) {
        userService.delete(id)
    }
}
```

## Service Layer

```kotlin
@Service
class UserService(
    private val userRepository: UserRepository,
    private val passwordEncoder: PasswordEncoder,
    private val eventPublisher: ApplicationEventPublisher,
) {

    @Transactional(readOnly = true)
    fun findById(id: Long): User =
        userRepository.findByIdOrNull(id)
            ?: throw NotFoundException("User with id=$id not found")

    @Transactional(readOnly = true)
    fun findAll(pageable: Pageable): Page<User> =
        userRepository.findAll(pageable)

    @Transactional
    fun create(request: CreateUserRequest): User {
        if (userRepository.existsByEmail(request.email)) {
            throw ConflictException("Email ${request.email} already in use")
        }
        val user = User(
            name = request.name,
            email = request.email,
            passwordHash = passwordEncoder.encode(request.password),
        )
        val saved = userRepository.save(user)
        eventPublisher.publishEvent(UserCreatedEvent(saved.id!!))
        return saved
    }

    @Transactional
    fun update(id: Long, request: UpdateUserRequest): User {
        val user = findById(id)
        val updated = user.copy(
            name = request.name ?: user.name,
            email = request.email ?: user.email,
        )
        return userRepository.save(updated)
    }

    @Transactional
    fun delete(id: Long) {
        val user = findById(id)
        userRepository.delete(user)
    }
}
```

## Repository Pattern

```kotlin
interface UserRepository : JpaRepository<User, Long> {

    fun existsByEmail(email: String): Boolean

    fun findByEmail(email: String): User?

    @Query("SELECT u FROM User u JOIN FETCH u.roles WHERE u.id = :id")
    fun findByIdWithRoles(@Param("id") id: Long): User?

    @EntityGraph(attributePaths = ["roles", "permissions"])
    override fun findAll(pageable: Pageable): Page<User>
}
```

## N+1 Prevention

```kotlin
// PROBLEM: N+1 queries
@OneToMany(mappedBy = "user")
val orders: List<Order> // each user triggers a separate query for orders

// SOLUTION 1: JOIN FETCH in JPQL
@Query("SELECT u FROM User u JOIN FETCH u.orders WHERE u.id = :id")
fun findByIdWithOrders(id: Long): User?

// SOLUTION 2: @EntityGraph
@EntityGraph(attributePaths = ["orders"])
fun findById(id: Long): User?

// SOLUTION 3: @BatchSize on the collection
@OneToMany(mappedBy = "user")
@BatchSize(size = 50)
val orders: List<Order>

// SOLUTION 4: Projection/DTO query
@Query("SELECT new com.example.dto.UserOrderSummary(u.name, COUNT(o)) FROM User u LEFT JOIN u.orders o GROUP BY u.name")
fun findUserOrderSummaries(): List<UserOrderSummary>
```

## Transaction Patterns

```kotlin
// Read-only transaction: performance optimization, no dirty checking
@Transactional(readOnly = true)
fun findAll(): List<User>

// Default: read-write transaction
@Transactional
fun create(request: CreateUserRequest): User

// Propagation: REQUIRES_NEW for independent transaction
@Transactional(propagation = Propagation.REQUIRES_NEW)
fun logAuditEvent(event: AuditEvent)

// Programmatic transaction (when annotation is insufficient)
@Autowired
lateinit var transactionTemplate: TransactionTemplate

fun complexOperation() {
    transactionTemplate.execute { status ->
        // transactional code
    }
}
```

## Caching

### Spring Cache with Caffeine

```kotlin
@Configuration
@EnableCaching
class CacheConfig {

    @Bean
    fun cacheManager(): CacheManager = CaffeineCacheManager().apply {
        setCaffeine(
            Caffeine.newBuilder()
                .maximumSize(1000)
                .expireAfterWrite(Duration.ofMinutes(10))
                .recordStats()
        )
    }
}

@Service
class ProductService(private val productRepository: ProductRepository) {

    @Cacheable(value = ["products"], key = "#id")
    fun findById(id: Long): Product = productRepository.findByIdOrNull(id)
        ?: throw NotFoundException("Product $id not found")

    @CacheEvict(value = ["products"], key = "#id")
    fun update(id: Long, request: UpdateProductRequest): Product { ... }

    @CacheEvict(value = ["products"], allEntries = true)
    fun clearCache() { }
}
```

### Cache with Redis

```kotlin
@Configuration
@EnableCaching
class RedisCacheConfig {

    @Bean
    fun cacheManager(connectionFactory: RedisConnectionFactory): RedisCacheManager {
        val defaultConfig = RedisCacheConfiguration.defaultCacheConfig()
            .entryTtl(Duration.ofMinutes(30))
            .serializeValuesWith(
                RedisSerializationContext.SerializationPair.fromSerializer(
                    GenericJackson2JsonRedisSerializer()
                )
            )
            .disableCachingNullValues()

        return RedisCacheManager.builder(connectionFactory)
            .cacheDefaults(defaultConfig)
            .withCacheConfiguration("products", defaultConfig.entryTtl(Duration.ofHours(1)))
            .build()
    }
}
```

## Error Handling

### Exception Hierarchy

```kotlin
sealed class DomainException(
    message: String,
    cause: Throwable? = null,
) : RuntimeException(message, cause)

class NotFoundException(message: String) : DomainException(message)
class ValidationException(val errors: List<FieldError>) : DomainException("Validation failed")
class ConflictException(message: String) : DomainException(message)
class ForbiddenException(message: String) : DomainException(message)

data class FieldError(val field: String, val message: String)
```

### Global Exception Handler

```kotlin
@RestControllerAdvice
class GlobalExceptionHandler {

    private val logger = LoggerFactory.getLogger(javaClass)

    @ExceptionHandler(NotFoundException::class)
    fun handleNotFound(ex: NotFoundException): ProblemDetail =
        ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, ex.message!!)

    @ExceptionHandler(ConflictException::class)
    fun handleConflict(ex: ConflictException): ProblemDetail =
        ProblemDetail.forStatusAndDetail(HttpStatus.CONFLICT, ex.message!!)

    @ExceptionHandler(ValidationException::class)
    fun handleValidation(ex: ValidationException): ProblemDetail =
        ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, ex.message!!).apply {
            setProperty("errors", ex.errors)
        }

    @ExceptionHandler(MethodArgumentNotValidException::class)
    fun handleBindingErrors(ex: MethodArgumentNotValidException): ProblemDetail {
        val errors = ex.bindingResult.fieldErrors.map { FieldError(it.field, it.defaultMessage ?: "") }
        return ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, "Validation failed").apply {
            setProperty("errors", errors)
        }
    }

    @ExceptionHandler(Exception::class)
    fun handleUnexpected(ex: Exception): ProblemDetail {
        logger.error("Unexpected error", ex)
        return ProblemDetail.forStatusAndDetail(
            HttpStatus.INTERNAL_SERVER_ERROR,
            "An unexpected error occurred"
        )
    }
}
```

## Retry with Resilience4j

```kotlin
@Service
class PaymentService(private val paymentClient: PaymentClient) {

    @Retry(name = "payment", fallbackMethod = "paymentFallback")
    fun processPayment(request: PaymentRequest): PaymentResult =
        paymentClient.charge(request)

    fun paymentFallback(request: PaymentRequest, ex: Exception): PaymentResult {
        logger.error("Payment failed after retries for order=${request.orderId}", ex)
        return PaymentResult.Error(ex)
    }
}
```

```yaml
# application.yml
resilience4j:
  retry:
    instances:
      payment:
        max-attempts: 3
        wait-duration: 1s
        exponential-backoff-multiplier: 2
        retry-exceptions:
          - java.io.IOException
          - java.util.concurrent.TimeoutException
        ignore-exceptions:
          - com.example.ValidationException
```

## Rate Limiting with Bucket4j

```kotlin
@Configuration
class RateLimitConfig {

    @Bean
    fun rateLimitFilter(): FilterRegistrationBean<RateLimitFilter> {
        val registration = FilterRegistrationBean<RateLimitFilter>()
        registration.filter = RateLimitFilter()
        registration.addUrlPatterns("/api/*")
        return registration
    }
}

class RateLimitFilter : OncePerRequestFilter() {

    private val buckets = ConcurrentHashMap<String, Bucket>()

    override fun doFilterInternal(
        request: HttpServletRequest,
        response: HttpServletResponse,
        filterChain: FilterChain,
    ) {
        val clientIp = request.remoteAddr
        val bucket = buckets.computeIfAbsent(clientIp) { createBucket() }

        if (bucket.tryConsume(1)) {
            filterChain.doFilter(request, response)
        } else {
            response.status = HttpStatus.TOO_MANY_REQUESTS.value()
            response.contentType = MediaType.APPLICATION_JSON_VALUE
            response.writer.write("""{"error": "Rate limit exceeded"}""")
        }
    }

    private fun createBucket(): Bucket = Bucket.builder()
        .addLimit(
            BandwidthBuilder.builder()
                .capacity(100)
                .refillGreedy(100, Duration.ofMinutes(1))
                .build()
        )
        .build()
}
```

## Structured Logging

```kotlin
import org.slf4j.LoggerFactory
import org.slf4j.MDC

class UserService(private val repository: UserRepository) {

    private val logger = LoggerFactory.getLogger(javaClass)

    fun findById(id: Long): User {
        MDC.put("userId", id.toString())
        try {
            logger.info("Fetching user")
            val user = repository.findByIdOrNull(id)
                ?: throw NotFoundException("User $id not found").also {
                    logger.warn("User not found")
                }
            logger.debug("User found: name={}", user.name)
            return user
        } finally {
            MDC.remove("userId")
        }
    }
}
```

### MDC Filter for Request Tracing

```kotlin
@Component
class RequestIdFilter : OncePerRequestFilter() {

    override fun doFilterInternal(
        request: HttpServletRequest,
        response: HttpServletResponse,
        filterChain: FilterChain,
    ) {
        val requestId = request.getHeader("X-Request-ID") ?: UUID.randomUUID().toString()
        MDC.put("requestId", requestId)
        response.setHeader("X-Request-ID", requestId)
        try {
            filterChain.doFilter(request, response)
        } finally {
            MDC.clear()
        }
    }
}
```

### Logback Pattern

```xml
<pattern>%d{ISO8601} [%thread] %-5level %logger{36} [%X{requestId}] [%X{userId}] - %msg%n</pattern>
```

## Background Jobs

```kotlin
@Configuration
@EnableScheduling
@EnableAsync
class AsyncConfig {

    @Bean
    fun taskExecutor(): TaskExecutor = ThreadPoolTaskExecutor().apply {
        corePoolSize = 5
        maxPoolSize = 10
        queueCapacity = 100
        setThreadNamePrefix("async-")
        initialize()
    }
}

@Service
class ReportService(private val reportRepository: ReportRepository) {

    @Scheduled(cron = "0 0 2 * * *") // daily at 2 AM
    fun generateDailyReport() {
        logger.info("Starting daily report generation")
        // generate report
    }

    @Async
    fun generateReportAsync(request: ReportRequest): CompletableFuture<Report> {
        val report = generateReport(request)
        return CompletableFuture.completedFuture(report)
    }
}
```

## Spring Security JWT Flow

```kotlin
@Configuration
@EnableWebSecurity
class SecurityConfig(private val jwtFilter: JwtAuthenticationFilter) {

    @Bean
    fun securityFilterChain(http: HttpSecurity): SecurityFilterChain = http
        .csrf { it.disable() }
        .sessionManagement { it.sessionCreationPolicy(SessionCreationPolicy.STATELESS) }
        .authorizeHttpRequests {
            it
                .requestMatchers("/api/v1/auth/**").permitAll()
                .requestMatchers("/actuator/health").permitAll()
                .requestMatchers(HttpMethod.GET, "/api/v1/products/**").permitAll()
                .anyRequest().authenticated()
        }
        .addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter::class.java)
        .build()
}
```
