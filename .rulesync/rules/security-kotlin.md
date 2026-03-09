---
root: false
targets: ["claudecode"]
description: "Kotlin security: input validation, null safety as security, serialization, coroutine safety"
globs: ["*.kt", "*.kts"]
---

# Kotlin Security

## Input Validation

- Use `require()` for argument validation at function entry points
- Use `check()` for state validation
- Validate all external input before processing

```kotlin
fun createUser(email: String, age: Int): User {
    require(email.contains("@")) { "Invalid email format: must contain @" }
    require(age in 0..150) { "Invalid age: must be between 0 and 150" }
    // ...
}
```

## Parameterized Queries

- JDBC: use `PreparedStatement` with `?` placeholders, never string concatenation
- JPA: use `@Param` named parameters in `@Query` annotations
- Exposed DSL: use the type-safe query builder
- jOOQ: use the type-safe DSL (inherently safe from injection)

```kotlin
// WRONG
@Query("SELECT u FROM User u WHERE u.email = '$email'")

// CORRECT
@Query("SELECT u FROM User u WHERE u.email = :email")
fun findByEmail(@Param("email") email: String): User?
```

## Secret Management

- Load secrets from environment variables or a secret manager
- Validate all required secrets are present at startup using `requireNotNull()`
- Never hardcode secrets in source code, config files, or test fixtures
- Use separate secret values per environment

```kotlin
val dbPassword = requireNotNull(System.getenv("DB_PASSWORD")) {
    "DB_PASSWORD environment variable is required"
}
```

## Null Safety as Security

- Kotlin's null safety prevents entire classes of NPE vulnerabilities
- Never use `!!` — it bypasses safety and can cause crashes
- Use nullable return types to represent "not found" rather than throwing exceptions
- Validate nullable input at system boundaries

## Coroutine Resource Safety

- Always clean up resources in `finally` blocks
- Use `.use {}` extension for `Closeable` resources
- Handle coroutine cancellation: resources must be released even on cancellation
- Use `withTimeout()` to prevent indefinite blocking

```kotlin
suspend fun readFile(path: Path): String =
    withContext(Dispatchers.IO) {
        Files.newBufferedReader(path).use { reader ->
            reader.readText()
        }
    }
```

## Serialization Security

- Use `kotlinx.serialization` with explicit `@Serializable` annotations
- Configure strict mode: reject unknown keys by default
- Validate deserialized values after parsing (range checks, format checks)
- Avoid `Map<String, Any>` deserialization — use typed data classes
- Never deserialize untrusted data into arbitrary types

```kotlin
@Serializable
data class UserRequest(
    val name: String,
    val email: String
) {
    init {
        require(name.isNotBlank()) { "Name must not be blank" }
        require(email.contains("@")) { "Invalid email format" }
    }
}
```

## Dependency Security

- Use OWASP Dependency-Check Gradle plugin to scan for known vulnerabilities
- Review transitive dependencies periodically
- Keep dependencies up to date, especially security-related libraries

## Logging Security

- Never log sensitive data: passwords, tokens, PII, credit card numbers
- Use parameterized logging to prevent log injection
- Sanitize user input before including it in log messages
