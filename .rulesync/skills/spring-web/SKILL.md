---
name: spring-web
description: "Spring Web MVC: REST controllers, request mapping, validation, exception handling, interceptors"
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Spring Web MVC

Comprehensive guide for building REST APIs with Spring Web MVC: controllers, validation, exception handling, interceptors, and CORS.

## REST Controllers

### Kotlin

```kotlin
@RestController
@RequestMapping("/api/v1/orders")
class OrderController(
    private val orderService: OrderService
) {

    @GetMapping
    fun listOrders(
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "20") size: Int,
        @RequestParam(required = false) status: OrderStatus?
    ): Page<OrderResponse> =
        orderService.findAll(status, PageRequest.of(page, size))

    @GetMapping("/{id}")
    fun getOrder(@PathVariable id: Long): ResponseEntity<OrderResponse> =
        orderService.findById(id)
            ?.let { ResponseEntity.ok(it) }
            ?: ResponseEntity.notFound().build()

    @PostMapping
    fun createOrder(
        @Valid @RequestBody request: CreateOrderRequest
    ): ResponseEntity<OrderResponse> {
        val order = orderService.create(request)
        val location = URI.create("/api/v1/orders/${order.id}")
        return ResponseEntity.created(location).body(order)
    }

    @PutMapping("/{id}")
    fun updateOrder(
        @PathVariable id: Long,
        @Valid @RequestBody request: UpdateOrderRequest
    ): OrderResponse =
        orderService.update(id, request)

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    fun deleteOrder(@PathVariable id: Long) {
        orderService.delete(id)
    }
}
```

### Java

```java
@RestController
@RequestMapping("/api/v1/orders")
public class OrderController {

    private final OrderService orderService;

    public OrderController(OrderService orderService) {
        this.orderService = orderService;
    }

    @GetMapping
    public Page<OrderResponse> listOrders(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) OrderStatus status) {
        return orderService.findAll(status, PageRequest.of(page, size));
    }

    @GetMapping("/{id}")
    public ResponseEntity<OrderResponse> getOrder(@PathVariable Long id) {
        return orderService.findById(id)
            .map(ResponseEntity::ok)
            .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping
    public ResponseEntity<OrderResponse> createOrder(
            @Valid @RequestBody CreateOrderRequest request) {
        OrderResponse order = orderService.create(request);
        URI location = URI.create("/api/v1/orders/" + order.id());
        return ResponseEntity.created(location).body(order);
    }

    @PutMapping("/{id}")
    public OrderResponse updateOrder(
            @PathVariable Long id,
            @Valid @RequestBody UpdateOrderRequest request) {
        return orderService.update(id, request);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteOrder(@PathVariable Long id) {
        orderService.delete(id);
    }
}
```

## Request and Response DTOs with Validation

### Kotlin

```kotlin
data class CreateOrderRequest(
    @field:NotBlank(message = "Customer ID is required")
    val customerId: String,

    @field:NotEmpty(message = "At least one item is required")
    val items: List<@Valid OrderItemRequest>,

    @field:Size(max = 500, message = "Notes must be at most 500 characters")
    val notes: String? = null
)

data class OrderItemRequest(
    @field:NotBlank
    val productId: String,

    @field:Min(1)
    @field:Max(999)
    val quantity: Int,

    @field:DecimalMin("0.01")
    val unitPrice: BigDecimal
)

data class OrderResponse(
    val id: Long,
    val customerId: String,
    val items: List<OrderItemResponse>,
    val totalAmount: BigDecimal,
    val status: OrderStatus,
    val createdAt: Instant
)
```

### Java

```java
public record CreateOrderRequest(
    @NotBlank(message = "Customer ID is required")
    String customerId,

    @NotEmpty(message = "At least one item is required")
    List<@Valid OrderItemRequest> items,

    @Size(max = 500, message = "Notes must be at most 500 characters")
    String notes
) {}

public record OrderItemRequest(
    @NotBlank String productId,
    @Min(1) @Max(999) int quantity,
    @DecimalMin("0.01") BigDecimal unitPrice
) {}

public record OrderResponse(
    Long id,
    String customerId,
    List<OrderItemResponse> items,
    BigDecimal totalAmount,
    OrderStatus status,
    Instant createdAt
) {}
```

## ResponseEntity Patterns

```kotlin
// Conditional response
@GetMapping("/{id}")
fun getOrder(@PathVariable id: Long): ResponseEntity<OrderResponse> =
    orderService.findById(id)
        ?.let { ResponseEntity.ok(it) }
        ?: ResponseEntity.notFound().build()

// Created with location header
@PostMapping
fun create(@Valid @RequestBody request: CreateOrderRequest): ResponseEntity<OrderResponse> {
    val order = orderService.create(request)
    return ResponseEntity
        .created(URI.create("/api/v1/orders/${order.id}"))
        .body(order)
}

// No content
@DeleteMapping("/{id}")
fun delete(@PathVariable id: Long): ResponseEntity<Void> {
    orderService.delete(id)
    return ResponseEntity.noContent().build()
}

// Custom headers
@GetMapping("/export")
fun export(): ResponseEntity<ByteArray> {
    val data = orderService.exportCsv()
    return ResponseEntity.ok()
        .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=orders.csv")
        .contentType(MediaType.APPLICATION_OCTET_STREAM)
        .body(data)
}
```

## Global Exception Handling with ProblemDetail (RFC 7807)

### Kotlin

```kotlin
@RestControllerAdvice
class GlobalExceptionHandler {

    @ExceptionHandler(EntityNotFoundException::class)
    fun handleNotFound(ex: EntityNotFoundException): ProblemDetail =
        ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, ex.message ?: "Resource not found")
            .apply {
                title = "Resource Not Found"
                setProperty("timestamp", Instant.now())
            }

    @ExceptionHandler(MethodArgumentNotValidException::class)
    fun handleValidation(ex: MethodArgumentNotValidException): ProblemDetail =
        ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, "Validation failed")
            .apply {
                title = "Validation Error"
                setProperty("errors", ex.bindingResult.fieldErrors.map { error ->
                    mapOf(
                        "field" to error.field,
                        "message" to (error.defaultMessage ?: "Invalid value"),
                        "rejectedValue" to error.rejectedValue
                    )
                })
            }

    @ExceptionHandler(AccessDeniedException::class)
    fun handleAccessDenied(ex: AccessDeniedException): ProblemDetail =
        ProblemDetail.forStatusAndDetail(HttpStatus.FORBIDDEN, "Access denied")

    @ExceptionHandler(ConflictException::class)
    fun handleConflict(ex: ConflictException): ProblemDetail =
        ProblemDetail.forStatusAndDetail(HttpStatus.CONFLICT, ex.message ?: "Conflict")

    @ExceptionHandler(Exception::class)
    fun handleGeneric(ex: Exception, request: WebRequest): ProblemDetail {
        // Log full exception server-side, return safe message to client
        logger.error("Unhandled exception for request: ${request.getDescription(false)}", ex)
        return ProblemDetail.forStatusAndDetail(
            HttpStatus.INTERNAL_SERVER_ERROR,
            "An unexpected error occurred"
        )
    }

    companion object {
        private val logger = LoggerFactory.getLogger(GlobalExceptionHandler::class.java)
    }
}
```

### Java

```java
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger logger = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(EntityNotFoundException.class)
    public ProblemDetail handleNotFound(EntityNotFoundException ex) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
            HttpStatus.NOT_FOUND, ex.getMessage());
        problem.setTitle("Resource Not Found");
        problem.setProperty("timestamp", Instant.now());
        return problem;
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ProblemDetail handleValidation(MethodArgumentNotValidException ex) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
            HttpStatus.BAD_REQUEST, "Validation failed");
        problem.setTitle("Validation Error");
        List<Map<String, Object>> errors = ex.getBindingResult().getFieldErrors().stream()
            .map(error -> Map.<String, Object>of(
                "field", error.getField(),
                "message", Objects.requireNonNullElse(error.getDefaultMessage(), "Invalid value"),
                "rejectedValue", Objects.toString(error.getRejectedValue(), "null")
            ))
            .toList();
        problem.setProperty("errors", errors);
        return problem;
    }

    @ExceptionHandler(Exception.class)
    public ProblemDetail handleGeneric(Exception ex, WebRequest request) {
        logger.error("Unhandled exception for request: {}", request.getDescription(false), ex);
        return ProblemDetail.forStatusAndDetail(
            HttpStatus.INTERNAL_SERVER_ERROR, "An unexpected error occurred");
    }
}
```

## Custom Domain Exceptions

```kotlin
sealed class DomainException(message: String) : RuntimeException(message)

class EntityNotFoundException(entity: String, id: Any) :
    DomainException("$entity with id $id not found")

class ConflictException(message: String) : DomainException(message)

class BusinessRuleViolationException(message: String) : DomainException(message)
```

## HandlerInterceptor

### Kotlin

```kotlin
@Component
class RequestLoggingInterceptor : HandlerInterceptor {

    override fun preHandle(
        request: HttpServletRequest,
        response: HttpServletResponse,
        handler: Any
    ): Boolean {
        request.setAttribute("startTime", System.currentTimeMillis())
        logger.info("→ {} {} from {}", request.method, request.requestURI, request.remoteAddr)
        return true
    }

    override fun afterCompletion(
        request: HttpServletRequest,
        response: HttpServletResponse,
        handler: Any,
        ex: Exception?
    ) {
        val startTime = request.getAttribute("startTime") as? Long ?: return
        val duration = System.currentTimeMillis() - startTime
        logger.info("← {} {} [{}] in {}ms",
            request.method, request.requestURI, response.status, duration)
    }

    companion object {
        private val logger = LoggerFactory.getLogger(RequestLoggingInterceptor::class.java)
    }
}

@Configuration
class WebMvcConfig(
    private val loggingInterceptor: RequestLoggingInterceptor
) : WebMvcConfigurer {

    override fun addInterceptors(registry: InterceptorRegistry) {
        registry.addInterceptor(loggingInterceptor)
            .addPathPatterns("/api/**")
            .excludePathPatterns("/api/health")
    }
}
```

## Content Negotiation

```yaml
spring:
  mvc:
    contentnegotiation:
      favor-parameter: true
      parameter-name: format
      media-types:
        json: application/json
        xml: application/xml
```

```kotlin
@GetMapping(value = ["/{id}"], produces = [MediaType.APPLICATION_JSON_VALUE, MediaType.APPLICATION_XML_VALUE])
fun getOrder(@PathVariable id: Long): OrderResponse =
    orderService.findById(id) ?: throw EntityNotFoundException("Order", id)
```

## File Upload

### Kotlin

```kotlin
@RestController
@RequestMapping("/api/v1/files")
class FileUploadController(
    private val storageService: StorageService
) {

    @PostMapping(consumes = [MediaType.MULTIPART_FORM_DATA_VALUE])
    fun upload(
        @RequestParam("file") file: MultipartFile,
        @RequestParam("description", required = false) description: String?
    ): ResponseEntity<FileResponse> {
        if (file.isEmpty) {
            throw BadRequestException("File must not be empty")
        }
        if (file.size > 10_000_000) {
            throw BadRequestException("File size must be under 10MB")
        }
        val stored = storageService.store(file, description)
        return ResponseEntity.created(URI.create("/api/v1/files/${stored.id}")).body(stored)
    }

    @GetMapping("/{id}")
    fun download(@PathVariable id: String): ResponseEntity<Resource> {
        val file = storageService.load(id)
        return ResponseEntity.ok()
            .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"${file.filename}\"")
            .contentType(MediaType.parseMediaType(file.contentType))
            .body(file.resource)
    }
}
```

### Configuration

```yaml
spring:
  servlet:
    multipart:
      max-file-size: 10MB
      max-request-size: 10MB
```

## CORS Configuration

### Kotlin

```kotlin
@Configuration
class CorsConfig : WebMvcConfigurer {

    override fun addCorsMappings(registry: CorsRegistry) {
        registry.addMapping("/api/**")
            .allowedOrigins("https://app.example.com", "https://admin.example.com")
            .allowedMethods("GET", "POST", "PUT", "DELETE", "PATCH")
            .allowedHeaders("*")
            .allowCredentials(true)
            .maxAge(3600)
    }
}
```

### Java

```java
@Configuration
public class CorsConfig implements WebMvcConfigurer {

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/api/**")
            .allowedOrigins("https://app.example.com", "https://admin.example.com")
            .allowedMethods("GET", "POST", "PUT", "DELETE", "PATCH")
            .allowedHeaders("*")
            .allowCredentials(true)
            .maxAge(3600);
    }
}
```

Per-controller or per-method CORS:

```kotlin
@CrossOrigin(origins = ["https://app.example.com"])
@GetMapping("/public-data")
fun getPublicData(): List<PublicItem> = service.findPublicItems()
```

## Best Practices

1. **Use DTOs** — never expose entity classes directly in controllers
2. **Validate all input** — @Valid on @RequestBody, constraints on @RequestParam
3. **Return ProblemDetail** — follow RFC 7807 for consistent error responses
4. **Use ResponseEntity** — for explicit control over status codes and headers
5. **Keep controllers thin** — delegate business logic to service layer
6. **Version your API** — use path versioning `/api/v1/`
7. **Paginate collections** — always use Pageable for list endpoints
8. **Log server-side, sanitize client-side** — never leak stack traces to clients
9. **Use @ResponseStatus** — for simple status-only responses (204 No Content)
10. **Configure CORS explicitly** — never use `allowedOrigins("*")` with credentials
