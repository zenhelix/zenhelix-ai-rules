---
name: api-design
description: "REST API design: resource naming, HTTP methods, status codes, pagination, versioning, error handling"
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# REST API Design Reference

## Resource Naming

- Use **nouns**, not verbs: `/users`, not `/getUsers`
- **Plural** form: `/users`, `/orders`, `/products`
- **Lowercase** with **kebab-case**: `/order-items`, not `/orderItems`
- **Hierarchical** for sub-resources: `/users/{id}/orders`
- No trailing slashes: `/users`, not `/users/`
- No file extensions: `/users/42`, not `/users/42.json`

### Examples

```
GET    /api/v1/users              # List users
GET    /api/v1/users/{id}         # Get user
POST   /api/v1/users              # Create user
PUT    /api/v1/users/{id}         # Full update
PATCH  /api/v1/users/{id}         # Partial update
DELETE /api/v1/users/{id}         # Delete user
GET    /api/v1/users/{id}/orders  # List user's orders
```

## HTTP Methods

| Method | Semantics        | Safe | Idempotent | Request Body | Response Body  |
|--------|------------------|------|------------|--------------|----------------|
| GET    | Read resource(s) | Yes  | Yes        | No           | Yes            |
| POST   | Create resource  | No   | No         | Yes          | Yes (201)      |
| PUT    | Full replace     | No   | Yes        | Yes          | Yes (200)      |
| PATCH  | Partial update   | No   | No         | Yes          | Yes (200)      |
| DELETE | Remove resource  | No   | Yes        | No           | 204 No Content |

## Status Codes

### Success (2xx)

| Code           | When                       | Example                                   |
|----------------|----------------------------|-------------------------------------------|
| 200 OK         | Successful GET, PUT, PATCH | Return resource                           |
| 201 Created    | Successful POST            | Return created resource + Location header |
| 204 No Content | Successful DELETE          | No body                                   |

### Client Error (4xx)

| Code                     | When                             | Example                           |
|--------------------------|----------------------------------|-----------------------------------|
| 400 Bad Request          | Malformed request                | Invalid JSON                      |
| 401 Unauthorized         | Not authenticated                | Missing/invalid token             |
| 403 Forbidden            | Authenticated but not authorized | Insufficient permissions          |
| 404 Not Found            | Resource does not exist          | Unknown ID                        |
| 409 Conflict             | State conflict                   | Duplicate email, version mismatch |
| 422 Unprocessable Entity | Validation failure               | Invalid field values              |
| 429 Too Many Requests    | Rate limit exceeded              | Include Retry-After header        |

### Server Error (5xx)

| Code                      | When                      |
|---------------------------|---------------------------|
| 500 Internal Server Error | Unexpected server error   |
| 502 Bad Gateway           | Upstream service failure  |
| 503 Service Unavailable   | Overloaded or maintenance |

## Response Format

### Success Response

```json
{
  "data": {
    "id": 42,
    "email": "user@example.com",
    "name": "John Doe"
  }
}
```

### Paginated Response

```json
{
  "data": [
    { "id": 1, "name": "Alice" },
    { "id": 2, "name": "Bob" }
  ],
  "meta": {
    "page": 0,
    "size": 20,
    "totalElements": 142,
    "totalPages": 8
  }
}
```

### Error Response (RFC 7807 ProblemDetail)

```json
{
  "type": "https://api.example.com/problems/validation-error",
  "title": "Validation Failed",
  "status": 422,
  "detail": "One or more fields have invalid values",
  "instance": "/api/v1/users",
  "errors": [
    { "field": "email", "message": "must be a valid email address" },
    { "field": "name", "message": "must not be blank" }
  ]
}
```

## Kotlin Spring Controller

```kotlin
@RestController
@RequestMapping("/api/v1/users")
class UserController(private val userService: UserService) {

    @GetMapping
    fun list(
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "20") size: Int,
        @RequestParam(required = false) status: UserStatus?
    ): ResponseEntity<PageResponse<UserResponse>> {
        val result = userService.findAll(status, PageRequest.of(page, size))
        return ResponseEntity.ok(
            PageResponse(
                data = result.content.map { it.toResponse() },
                meta = PaginationMeta.from(result)
            )
        )
    }

    @GetMapping("/{id}")
    fun getById(@PathVariable id: Long): ResponseEntity<DataResponse<UserResponse>> {
        val user = userService.findById(id)
        return ResponseEntity.ok(DataResponse(data = user.toResponse()))
    }

    @PostMapping
    fun create(@Valid @RequestBody request: CreateUserRequest): ResponseEntity<DataResponse<UserResponse>> {
        val user = userService.create(request)
        val location = URI.create("/api/v1/users/${user.id}")
        return ResponseEntity.created(location)
            .body(DataResponse(data = user.toResponse()))
    }

    @PutMapping("/{id}")
    fun update(
        @PathVariable id: Long,
        @Valid @RequestBody request: UpdateUserRequest
    ): ResponseEntity<DataResponse<UserResponse>> {
        val user = userService.update(id, request)
        return ResponseEntity.ok(DataResponse(data = user.toResponse()))
    }

    @PatchMapping("/{id}")
    fun patch(
        @PathVariable id: Long,
        @Valid @RequestBody request: PatchUserRequest
    ): ResponseEntity<DataResponse<UserResponse>> {
        val user = userService.patch(id, request)
        return ResponseEntity.ok(DataResponse(data = user.toResponse()))
    }

    @DeleteMapping("/{id}")
    fun delete(@PathVariable id: Long): ResponseEntity<Void> {
        userService.delete(id)
        return ResponseEntity.noContent().build()
    }
}
```

## Java Spring Controller

```java
@RestController
@RequestMapping("/api/v1/users")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    @GetMapping
    public ResponseEntity<PageResponse<UserResponse>> list(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) UserStatus status) {
        Page<User> result = userService.findAll(status, PageRequest.of(page, size));
        List<UserResponse> data = result.getContent().stream()
            .map(UserResponse::from)
            .toList();
        return ResponseEntity.ok(new PageResponse<>(data, PaginationMeta.from(result)));
    }

    @GetMapping("/{id}")
    public ResponseEntity<DataResponse<UserResponse>> getById(@PathVariable Long id) {
        User user = userService.findById(id);
        return ResponseEntity.ok(new DataResponse<>(UserResponse.from(user)));
    }

    @PostMapping
    public ResponseEntity<DataResponse<UserResponse>> create(
            @Valid @RequestBody CreateUserRequest request) {
        User user = userService.create(request);
        URI location = URI.create("/api/v1/users/" + user.getId());
        return ResponseEntity.created(location)
            .body(new DataResponse<>(UserResponse.from(user)));
    }

    @PutMapping("/{id}")
    public ResponseEntity<DataResponse<UserResponse>> update(
            @PathVariable Long id,
            @Valid @RequestBody UpdateUserRequest request) {
        User user = userService.update(id, request);
        return ResponseEntity.ok(new DataResponse<>(UserResponse.from(user)));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        userService.delete(id);
        return ResponseEntity.noContent().build();
    }
}
```

## Response DTOs

```kotlin
// Kotlin
data class DataResponse<T>(val data: T)

data class PageResponse<T>(
    val data: List<T>,
    val meta: PaginationMeta
)

data class PaginationMeta(
    val page: Int,
    val size: Int,
    val totalElements: Long,
    val totalPages: Int
) {
    companion object {
        fun from(page: Page<*>) = PaginationMeta(
            page = page.number,
            size = page.size,
            totalElements = page.totalElements,
            totalPages = page.totalPages
        )
    }
}
```

```java
// Java
public record DataResponse<T>(T data) {}

public record PageResponse<T>(List<T> data, PaginationMeta meta) {}

public record PaginationMeta(int page, int size, long totalElements, int totalPages) {
    public static PaginationMeta from(Page<?> page) {
        return new PaginationMeta(
            page.getNumber(), page.getSize(),
            page.getTotalElements(), page.getTotalPages()
        );
    }
}
```

## Error Handling with @ControllerAdvice

```kotlin
// Kotlin
@RestControllerAdvice
class GlobalExceptionHandler : ResponseEntityExceptionHandler() {

    @ExceptionHandler(ResourceNotFoundException::class)
    fun handleNotFound(ex: ResourceNotFoundException): ProblemDetail {
        val problem = ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, ex.message ?: "Resource not found")
        problem.title = "Not Found"
        problem.setProperty("timestamp", OffsetDateTime.now())
        return problem
    }

    @ExceptionHandler(ConflictException::class)
    fun handleConflict(ex: ConflictException): ProblemDetail {
        val problem = ProblemDetail.forStatusAndDetail(HttpStatus.CONFLICT, ex.message ?: "Conflict")
        problem.title = "Conflict"
        return problem
    }

    override fun handleMethodArgumentNotValid(
        ex: MethodArgumentNotValidException,
        headers: HttpHeaders,
        status: HttpStatusCode,
        request: WebRequest
    ): ResponseEntity<Any>? {
        val problem = ProblemDetail.forStatusAndDetail(HttpStatus.UNPROCESSABLE_ENTITY, "Validation failed")
        problem.title = "Validation Error"
        problem.setProperty("errors", ex.bindingResult.fieldErrors.map { fieldError ->
            mapOf("field" to fieldError.field, "message" to (fieldError.defaultMessage ?: "invalid"))
        })
        return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY).body(problem)
    }

    @ExceptionHandler(Exception::class)
    fun handleGeneric(ex: Exception): ProblemDetail {
        // Log the full exception server-side
        logger.error("Unexpected error", ex)
        // Return generic message to client (no internal details)
        return ProblemDetail.forStatusAndDetail(
            HttpStatus.INTERNAL_SERVER_ERROR,
            "An unexpected error occurred"
        )
    }
}
```

```java
// Java
@RestControllerAdvice
public class GlobalExceptionHandler extends ResponseEntityExceptionHandler {

    @ExceptionHandler(ResourceNotFoundException.class)
    public ProblemDetail handleNotFound(ResourceNotFoundException ex) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
            HttpStatus.NOT_FOUND, ex.getMessage());
        problem.setTitle("Not Found");
        return problem;
    }

    @ExceptionHandler(ConflictException.class)
    public ProblemDetail handleConflict(ConflictException ex) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
            HttpStatus.CONFLICT, ex.getMessage());
        problem.setTitle("Conflict");
        return problem;
    }

    @Override
    protected ResponseEntity<Object> handleMethodArgumentNotValid(
            MethodArgumentNotValidException ex,
            HttpHeaders headers,
            HttpStatusCode status,
            WebRequest request) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
            HttpStatus.UNPROCESSABLE_ENTITY, "Validation failed");
        problem.setTitle("Validation Error");
        problem.setProperty("errors", ex.getBindingResult().getFieldErrors().stream()
            .map(e -> Map.of("field", e.getField(), "message", e.getDefaultMessage()))
            .toList());
        return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY).body(problem);
    }
}
```

## Pagination

### Offset-Based (Simple Cases)

```kotlin
// Kotlin
@GetMapping("/orders")
fun list(
    @RequestParam(defaultValue = "0") page: Int,
    @RequestParam(defaultValue = "20") size: Int,
    @RequestParam(defaultValue = "createdAt,desc") sort: String
): ResponseEntity<PageResponse<OrderResponse>> {
    val pageable = PageRequest.of(page, size, Sort.by(parseSortParams(sort)))
    val result = orderService.findAll(pageable)
    return ResponseEntity.ok(PageResponse(
        data = result.content.map { it.toResponse() },
        meta = PaginationMeta.from(result)
    ))
}
```

### Cursor-Based (Large Datasets)

```kotlin
// Kotlin
data class CursorPage<T>(
    val data: List<T>,
    val nextCursor: String?,
    val hasMore: Boolean
)

@GetMapping("/events")
fun listEvents(
    @RequestParam(required = false) cursor: String?,
    @RequestParam(defaultValue = "50") limit: Int
): ResponseEntity<CursorPage<EventResponse>> {
    val decodedCursor = cursor?.let { decodeCursor(it) }
    val events = eventService.findAfter(decodedCursor, limit + 1)

    val hasMore = events.size > limit
    val page = events.take(limit)
    val nextCursor = if (hasMore) encodeCursor(page.last()) else null

    return ResponseEntity.ok(CursorPage(
        data = page.map { it.toResponse() },
        nextCursor = nextCursor,
        hasMore = hasMore
    ))
}

private fun encodeCursor(event: Event): String =
    Base64.getUrlEncoder().encodeToString("${event.createdAt}|${event.id}".toByteArray())

private fun decodeCursor(cursor: String): CursorData {
    val decoded = String(Base64.getUrlDecoder().decode(cursor))
    val (timestamp, id) = decoded.split("|")
    return CursorData(OffsetDateTime.parse(timestamp), id.toLong())
}
```

```java
// Java
public record CursorPage<T>(List<T> data, String nextCursor, boolean hasMore) {}

@GetMapping("/events")
public ResponseEntity<CursorPage<EventResponse>> listEvents(
        @RequestParam(required = false) String cursor,
        @RequestParam(defaultValue = "50") int limit) {
    CursorData decodedCursor = cursor != null ? decodeCursor(cursor) : null;
    List<Event> events = eventService.findAfter(decodedCursor, limit + 1);

    boolean hasMore = events.size() > limit;
    List<Event> page = events.subList(0, Math.min(events.size(), limit));
    String nextCursor = hasMore ? encodeCursor(page.get(page.size() - 1)) : null;

    return ResponseEntity.ok(new CursorPage<>(
        page.stream().map(EventResponse::from).toList(),
        nextCursor,
        hasMore
    ));
}
```

## Filtering and Sorting

```
GET /api/v1/orders?status=PENDING&minTotal=100&sort=-createdAt,+total
```

```kotlin
// Kotlin
@GetMapping("/orders")
fun list(
    @RequestParam(required = false) status: OrderStatus?,
    @RequestParam(required = false) minTotal: BigDecimal?,
    @RequestParam(required = false) maxTotal: BigDecimal?,
    @RequestParam(defaultValue = "-createdAt") sort: String,
    @RequestParam(defaultValue = "0") page: Int,
    @RequestParam(defaultValue = "20") size: Int
): ResponseEntity<PageResponse<OrderResponse>> {
    val filter = OrderFilter(status = status, minTotal = minTotal, maxTotal = maxTotal)
    val pageable = PageRequest.of(page, size, parseSort(sort))
    val result = orderService.findAll(filter, pageable)
    return ResponseEntity.ok(PageResponse(
        data = result.content.map { it.toResponse() },
        meta = PaginationMeta.from(result)
    ))
}

private fun parseSort(sort: String): Sort {
    val orders = sort.split(",").map { param ->
        val trimmed = param.trim()
        if (trimmed.startsWith("-")) {
            Sort.Order.desc(trimmed.substring(1))
        } else {
            Sort.Order.asc(trimmed.removePrefix("+"))
        }
    }
    return Sort.by(orders)
}
```

## Versioning

### URL Path Versioning (Preferred)

```
/api/v1/users
/api/v2/users
```

```kotlin
@RestController
@RequestMapping("/api/v1/users")
class UserV1Controller { ... }

@RestController
@RequestMapping("/api/v2/users")
class UserV2Controller { ... }
```

### Header Versioning (Alternative)

```
GET /api/users
Accept: application/vnd.myapp.v2+json
```

## Rate Limiting Headers

Include in responses:

```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 87
X-RateLimit-Reset: 1700000000
Retry-After: 30
```

```kotlin
// Kotlin - simple rate limit response headers
@Component
class RateLimitFilter : OncePerRequestFilter() {
    override fun doFilterInternal(
        request: HttpServletRequest,
        response: HttpServletResponse,
        filterChain: FilterChain
    ) {
        // After rate limit check
        response.setHeader("X-RateLimit-Limit", "100")
        response.setHeader("X-RateLimit-Remaining", remaining.toString())
        response.setHeader("X-RateLimit-Reset", resetTimestamp.toString())
        filterChain.doFilter(request, response)
    }
}
```

## Validation

```kotlin
// Kotlin
data class CreateUserRequest(
    @field:NotBlank(message = "Email is required")
    @field:Email(message = "Must be a valid email")
    val email: String,

    @field:NotBlank(message = "Name is required")
    @field:Size(min = 2, max = 100, message = "Name must be 2-100 characters")
    val name: String,

    @field:Size(max = 500, message = "Bio must not exceed 500 characters")
    val bio: String? = null
)
```

```java
// Java
public record CreateUserRequest(
    @NotBlank(message = "Email is required")
    @Email(message = "Must be a valid email")
    String email,

    @NotBlank(message = "Name is required")
    @Size(min = 2, max = 100, message = "Name must be 2-100 characters")
    String name,

    @Size(max = 500, message = "Bio must not exceed 500 characters")
    String bio
) {}
```

## API Design Checklist

- [ ] Resources are nouns, plural, kebab-case
- [ ] Correct HTTP methods for each operation
- [ ] Appropriate status codes (not just 200 for everything)
- [ ] Consistent response envelope (data + meta)
- [ ] ProblemDetail (RFC 7807) for errors
- [ ] Pagination on all list endpoints
- [ ] Validation on all inputs with clear error messages
- [ ] Versioning strategy decided and applied
- [ ] No sensitive data in error responses
- [ ] Rate limiting headers on all endpoints
- [ ] Location header on 201 Created responses
- [ ] Idempotent PUT and DELETE
- [ ] HATEOAS links if applicable
- [ ] Request/response DTOs separate from domain entities
- [ ] Consistent naming across all endpoints
