---
root: false
targets: ["claudecode"]
description: "Kotlin patterns: Result type, sealed state machines, delegation, DSL builders, Flow, coroutines"
globs: ["*.kt", "*.kts"]
---

# Kotlin Patterns

## Sealed Result Type

Use a sealed class for typed error handling instead of exceptions for expected failures:

```kotlin
sealed class AppResult<out T> {
    data class Success<T>(val data: T) : AppResult<T>()
    data class Failure(val error: AppError) : AppResult<Nothing>()
}

sealed class AppError {
    data class NotFound(val id: String) : AppError()
    data class Validation(val message: String) : AppError()
    data class Unexpected(val cause: Throwable) : AppError()
}

fun <T> AppResult<T>.getOrThrow(): T = when (this) {
    is AppResult.Success -> data
    is AppResult.Failure -> throw error.toException()
}
```

## Sealed State Machines

Model finite states with sealed types and exhaustive `when`:

```kotlin
sealed interface OrderState {
    data object Created : OrderState
    data class Paid(val paymentId: String) : OrderState
    data class Shipped(val trackingNumber: String) : OrderState
    data object Cancelled : OrderState
}

fun OrderState.nextAction(): String = when (this) {
    is OrderState.Created -> "Awaiting payment"
    is OrderState.Paid -> "Ready to ship"
    is OrderState.Shipped -> "In transit: $trackingNumber"
    is OrderState.Cancelled -> "No action needed"
}
```

## Delegation

Use `by` keyword to delegate interface implementation:

```kotlin
class LoggingRepository(
    private val delegate: UserRepository
) : UserRepository by delegate {
    override fun findById(id: Long): User? {
        log.info("Finding user by id: $id")
        return delegate.findById(id)
    }
}
```

## DSL Builders

Use `@DslMarker` for type-safe builders:

```kotlin
@DslMarker
annotation class QueryDsl

@QueryDsl
class QueryBuilder {
    var table: String = ""
    private val conditions = mutableListOf<String>()

    fun where(condition: String) { conditions.add(condition) }
    fun build(): Query = Query(table, conditions.toList())
}

fun query(block: QueryBuilder.() -> Unit): Query =
    QueryBuilder().apply(block).build()

// Usage
val q = query {
    table = "users"
    where("active = true")
    where("age > 18")
}
```

## Flow Patterns

```kotlin
// Convert callbacks to Flow
fun eventFlow(): Flow<Event> = callbackFlow {
    val listener = EventListener { event -> trySend(event) }
    register(listener)
    awaitClose { unregister(listener) }
}

// Share a cold Flow as hot StateFlow
val state: StateFlow<UiState> = repository.observe()
    .map { data -> UiState.Loaded(data) }
    .stateIn(scope, SharingStarted.WhileSubscribed(5000), UiState.Loading)
```

## Coroutine Patterns

```kotlin
// SupervisorJob: child failures don't cancel siblings
val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

// Parallel decomposition with structured concurrency
suspend fun fetchDashboard(): Dashboard = coroutineScope {
    val user = async { userService.getCurrent() }
    val stats = async { statsService.getRecent() }
    Dashboard(user.await(), stats.await())
}

// Switch context for blocking operations
suspend fun readConfig(): Config = withContext(Dispatchers.IO) {
    Files.readString(configPath).let { parseConfig(it) }
}
```

## Value Objects

Use inline value classes for type-safe wrappers with zero overhead:

```kotlin
@JvmInline
value class UserId(val value: Long) {
    init { require(value > 0) { "UserId must be positive" } }
}

@JvmInline
value class Email(val value: String) {
    init { require(value.contains("@")) { "Invalid email format" } }
}
```

## Inline Functions with Reified Types

```kotlin
inline fun <reified T> JsonNode.deserialize(): T =
    objectMapper.treeToValue(this, T::class.java)

// Usage: no class token needed
val user = jsonNode.deserialize<User>()
```

## Repository with Extension Functions

```kotlin
interface UserRepository {
    fun findById(id: UserId): User?
    fun findAll(): List<User>
    fun save(user: User): User
}

fun UserRepository.findByIdOrThrow(id: UserId): User =
    findById(id) ?: throw NotFoundException("User not found: $id")

fun UserRepository.findActive(): List<User> =
    findAll().filter { it.isActive }
```
