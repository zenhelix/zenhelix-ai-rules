---
name: coding-standards
description: "Coding standards: readability, KISS/DRY/YAGNI, error handling, type safety for Kotlin and Java"
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Coding Standards

## Readability

### Meaningful Names

```kotlin
// BAD
val d = 86400
fun proc(u: User): Boolean

// GOOD
val secondsPerDay = 86400
fun isEligibleForPromotion(user: User): Boolean
```

```java
// BAD
List<int[]> getThem() { ... }

// GOOD
List<Cell> getFlaggedCells() { ... }
```

### Small Functions

Each function should do ONE thing:

- 5-20 lines is ideal
- 50 lines maximum
- If you need comments to explain sections, extract functions instead
- Name functions after their intent, not their implementation

### Single Responsibility

Each class has ONE reason to change:

```kotlin
// BAD: handles validation, persistence, and notification
class UserService {
    fun register(request: RegisterRequest) {
        validate(request)
        val user = save(request)
        sendEmail(user)
    }
}

// GOOD: each concern separated
class UserRegistrationService(
    private val validator: UserValidator,
    private val repository: UserRepository,
    private val notifier: UserNotifier,
) {
    fun register(request: RegisterRequest): User {
        validator.validate(request)
        val user = repository.save(request.toUser())
        notifier.onRegistered(user)
        return user
    }
}
```

## KISS: Keep It Simple

Choose the simplest solution that correctly solves the problem:

```kotlin
// OVER-ENGINEERED
interface UserFinder<T : Identifiable> : GenericFinder<T, Long> {
    override fun findBySpec(spec: Specification<T>): List<T>
}

// KISS
interface UserRepository {
    fun findById(id: Long): User?
    fun findByEmail(email: String): User?
}
```

Avoid:

- Premature abstraction
- Generic type parameters unless truly needed
- Design patterns for the sake of patterns
- Framework features you do not need

## DRY: Don't Repeat Yourself

Extract when a pattern repeats THREE or more times, not before:

```kotlin
// First occurrence: inline is fine
// Second occurrence: note it, leave inline
// Third occurrence: extract

// Extracted utility
fun <T> T?.orThrow(message: () -> String): T =
    this ?: throw NotFoundException(message())

// Usage
val user = userRepository.findByIdOrNull(id).orThrow { "User $id not found" }
val order = orderRepository.findByIdOrNull(id).orThrow { "Order $id not found" }
val product = productRepository.findByIdOrNull(id).orThrow { "Product $id not found" }
```

## YAGNI: You Aren't Gonna Need It

Do not build for hypothetical future requirements:

```kotlin
// BAD: supports multiple notification channels "just in case"
interface NotificationChannel {
    fun send(message: Message)
}
class EmailChannel : NotificationChannel { ... }
class SmsChannel : NotificationChannel { ... }  // nobody asked for SMS
class PushChannel : NotificationChannel { ... } // nobody asked for push

// GOOD: build what is needed now
class EmailNotifier(private val mailSender: JavaMailSender) {
    fun sendWelcomeEmail(user: User) { ... }
}
// Add abstraction WHEN a second channel is actually needed
```

## Immutability

### Kotlin

```kotlin
// Use val, not var
val name: String = "Alice"

// Use immutable collections
val users: List<User> = repository.findAll()

// Use copy() for modifications
val updated = user.copy(name = "Bob")

// Data classes are naturally immutable with val properties
data class User(
    val id: Long,
    val name: String,
    val email: String,
)
```

### Java

```java
// Use records for immutable data
public record User(Long id, String name, String email) {}

// Use final fields
public final class Config {
    private final String host;
    private final int port;
}

// Use unmodifiable collections
var users = List.of(user1, user2);
var map = Map.of("key", "value");
var copy = List.copyOf(mutableList);
```

## Error Handling

### Custom Domain Exceptions

```kotlin
sealed class DomainException(message: String, cause: Throwable? = null) : RuntimeException(message, cause)

class NotFoundException(message: String) : DomainException(message)
class ValidationException(val errors: List<String>) : DomainException(errors.joinToString("; "))
class ConflictException(message: String) : DomainException(message)
class AccessDeniedException(message: String) : DomainException(message)
```

### Structured Error Responses

```kotlin
@RestControllerAdvice
class GlobalExceptionHandler {

    @ExceptionHandler(NotFoundException::class)
    fun handleNotFound(ex: NotFoundException): ProblemDetail =
        ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, ex.message ?: "Not found")

    @ExceptionHandler(ValidationException::class)
    fun handleValidation(ex: ValidationException): ProblemDetail =
        ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, ex.message ?: "Validation error")
}
```

### Never Swallow Exceptions

```kotlin
// BAD
try { riskyOperation() } catch (_: Exception) { }

// GOOD
try {
    riskyOperation()
} catch (e: SpecificException) {
    logger.error(e) { "Failed to perform risky operation for user=$userId" }
    throw ServiceException("Operation failed", e)
}
```

## Type Safety

### Sealed Classes for Finite States

```kotlin
sealed interface PaymentResult {
    data class Success(val transactionId: String, val amount: BigDecimal) : PaymentResult
    data class Declined(val reason: String) : PaymentResult
    data class Error(val exception: Throwable) : PaymentResult
}

// Compiler enforces exhaustive when
fun handle(result: PaymentResult): String = when (result) {
    is PaymentResult.Success -> "Paid: ${result.transactionId}"
    is PaymentResult.Declined -> "Declined: ${result.reason}"
    is PaymentResult.Error -> "Error: ${result.exception.message}"
}
```

### Avoid Stringly-Typed Code

```kotlin
// BAD
fun findUsers(role: String): List<User>  // what values are valid?

// GOOD
enum class Role { ADMIN, USER, MODERATOR }
fun findUsers(role: Role): List<User>
```

### Value Classes for Domain Primitives (Kotlin)

```kotlin
@JvmInline
value class UserId(val value: Long)

@JvmInline
value class Email(val value: String) {
    init { require(value.contains("@")) { "Invalid email: $value" } }
}
```

## Coroutine Best Practices (Kotlin)

```kotlin
// Use structured concurrency
class UserService(
    private val repository: UserRepository,
    private val notifier: UserNotifier,
) {
    // Let the caller manage the scope
    suspend fun register(request: RegisterRequest): User {
        val user = repository.save(request.toUser())
        notifier.onRegistered(user)
        return user
    }
}

// Parallel execution with coroutineScope
suspend fun fetchDashboard(userId: Long): Dashboard = coroutineScope {
    val userDeferred = async { userService.findById(userId) }
    val ordersDeferred = async { orderService.findByUserId(userId) }
    Dashboard(user = userDeferred.await(), orders = ordersDeferred.await())
}
```

## CompletableFuture Best Practices (Java)

```java
public CompletableFuture<Dashboard> fetchDashboard(Long userId) {
    var userFuture = userService.findById(userId);
    var ordersFuture = orderService.findByUserId(userId);

    return userFuture.thenCombine(ordersFuture, Dashboard::new)
        .orTimeout(5, TimeUnit.SECONDS)
        .exceptionally(ex -> {
            logger.error("Dashboard fetch failed for user={}", userId, ex);
            throw new ServiceException("Failed to load dashboard", ex);
        });
}
```

## REST API Conventions

- URLs: kebab-case, plural nouns — `/api/v1/user-accounts`
- HTTP methods: GET (read), POST (create), PUT (full update), PATCH (partial), DELETE
- Status codes: 200 (OK), 201 (Created), 204 (No Content), 400, 401, 403, 404, 409, 500
- Request/response bodies: camelCase JSON
- Pagination: `?page=0&size=20&sort=name,asc`
- Versioning: URL path (`/api/v1/`) or header

## Input Validation

```kotlin
data class CreateUserRequest(
    @field:NotBlank(message = "Name is required")
    @field:Size(min = 2, max = 100)
    val name: String,

    @field:NotBlank
    @field:Email(message = "Invalid email format")
    val email: String,

    @field:NotBlank
    @field:Size(min = 8, max = 128)
    val password: String,
)
```

Kotlin preconditions:
```kotlin
fun withdraw(amount: BigDecimal) {
    require(amount > BigDecimal.ZERO) { "Amount must be positive: $amount" }
    check(status == AccountStatus.ACTIVE) { "Account is not active" }
}
```

## File Organization

- Organize by feature/domain, not by type:
  ```
  user/
  ├── UserController.kt
  ├── UserService.kt
  ├── UserRepository.kt
  └── User.kt
  ```
- 200-400 lines per file is typical
- 800 lines maximum — split if larger
- One public class/interface per file (Kotlin allows related private classes)

## Code Smells Checklist

- Long functions (> 50 lines)
- Deep nesting (> 4 levels)
- Magic numbers/strings
- God classes (> 800 lines, too many responsibilities)
- Feature envy (method uses another class's data more than its own)
- Primitive obsession (String for email, Int for ID everywhere)
- Shotgun surgery (one change requires edits in many classes)
- Long parameter lists (> 4 parameters — use a data class/record)
