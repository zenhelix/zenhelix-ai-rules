---
root: false
targets: ["claudecode"]
description: "Kotlin coding style: immutability, null safety, coroutines, scope functions, idiomatic patterns"
globs: ["*.kt", "*.kts"]
---

# Kotlin Coding Style

## Immutability

- Prefer `val` over `var` in all cases
- Use `data class` with `copy()` for immutable updates
- Use immutable collections: `listOf()`, `mapOf()`, `setOf()`
- Use `toMutableList()` only within a local scope, return immutable

```kotlin
// WRONG: mutating in place
user.name = "new name"

// CORRECT: creating a new copy
val updated = user.copy(name = "new name")
```

## Null Safety

- Avoid `!!` — it defeats the purpose of null safety
- Use safe calls: `value?.property`
- Use `?.let {}` for nullable transformations
- Use Elvis operator: `value ?: default`
- Use `requireNotNull(value) { "descriptive message" }` when null is a programming error

## Extension Functions

- Add behavior to existing types without inheritance
- Keep extensions focused and discoverable
- Place extensions in a file named after the extended type (e.g., `StringExtensions.kt`)

## Coroutines

- Use structured concurrency: always launch within a scope
- Use `supervisorScope` when child failures should not cancel siblings
- Handle cancellation properly: check `isActive`, use `ensureActive()`
- Use `withContext(Dispatchers.IO)` for blocking operations
- Never use `GlobalScope` in production code

## Scope Functions

- `let` — null check + transformation: `value?.let { transform(it) }`
- `apply` — configure an object: `Builder().apply { field = value }`
- `also` — side effects: `value.also { log.info("Got $it") }`
- `run` — compute within scope: `service.run { fetchData() }`
- `with` — group calls on an object: `with(config) { validate(); apply() }`

## Naming Conventions

- `camelCase` for functions and properties
- `PascalCase` for classes, interfaces, objects, type aliases
- `UPPER_SNAKE_CASE` for compile-time constants (`const val`)
- Meaningful names: `calculateTotalPrice()` not `calc()`

## Sealed Types

- Use `sealed class` / `sealed interface` for restricted type hierarchies
- Always handle all branches in `when` expressions (exhaustive matching)
- Prefer sealed interfaces for flexibility (multiple inheritance)

## Preconditions

- `require(condition) { "message" }` — validate arguments (throws `IllegalArgumentException`)
- `check(condition) { "message" }` — validate state (throws `IllegalStateException`)
- Place preconditions at the top of functions

## Performance Patterns

- Use `Sequence` for lazy processing of large collections
- Use `@JvmInline value class` for type-safe wrappers without allocation overhead
- Use `inline` functions with `reified` type parameters for type-safe generics

## Singletons and Companions

- Use `object` for singletons
- Use `companion object` for factory methods and constants
- Name companion objects when they serve a specific role

## Logging

- Use SLF4J with KotlinLogging: `private val log = KotlinLogging.logger {}`
- Use structured logging with parameterized messages
- Never log sensitive data (passwords, tokens, PII)
