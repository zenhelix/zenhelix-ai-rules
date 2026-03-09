---
root: false
targets: ["claudecode"]
description: "Java coding style: modern Java 17+, records, sealed classes, Optional, streams, naming"
globs: ["*.java"]
---

# Java Coding Style

## Modern Java (17+)

### Records

Use records for immutable data carriers:

```java
public record UserDto(String name, String email, Instant createdAt) {
    public UserDto {
        Objects.requireNonNull(name, "name must not be null");
        Objects.requireNonNull(email, "email must not be null");
    }
}
```

### Sealed Classes

Use sealed types for restricted type hierarchies:

```java
public sealed interface Shape permits Circle, Rectangle, Triangle {
    double area();
}

public record Circle(double radius) implements Shape {
    public double area() { return Math.PI * radius * radius; }
}
```

### Pattern Matching

```java
// instanceof pattern matching (Java 16+)
if (shape instanceof Circle c) {
    return c.radius();
}

// Switch pattern matching (Java 21+)
return switch (shape) {
    case Circle c -> Math.PI * c.radius() * c.radius();
    case Rectangle r -> r.width() * r.height();
    case Triangle t -> 0.5 * t.base() * t.height();
};
```

### Text Blocks

Use text blocks for multi-line strings:

```java
String query = """
    SELECT u.id, u.name, u.email
    FROM users u
    WHERE u.active = true
    ORDER BY u.name
    """;
```

## Immutability

- Declare fields `final` wherever possible
- Use unmodifiable collections: `List.of()`, `Map.of()`, `Set.of()`
- Return unmodifiable views: `Collections.unmodifiableList()`
- Use records instead of mutable POJOs
- Never expose mutable internal state

## Optional

- Use `Optional` as a return type only, never as a field or method parameter
- Prefer `orElseThrow()` over `get()`
- Use `map()` / `flatMap()` for transformations
- Use `orElse()` or `orElseGet()` for defaults

```java
// WRONG
Optional<User> userOpt = findById(id);
User user = userOpt.get();

// CORRECT
User user = findById(id)
    .orElseThrow(() -> new NotFoundException("User not found: " + id));
```

## Streams

- Use `filter()` / `map()` / `collect()` for collection transformations
- Avoid side effects in stream operations
- Prefer method references: `User::getName` over `u -> u.getName()`
- Use `toList()` (Java 16+) instead of `collect(Collectors.toList())`
- Keep stream pipelines readable: one operation per line

## Naming Conventions

- `camelCase` for methods and variables
- `PascalCase` for classes and interfaces
- `UPPER_SNAKE_CASE` for constants (`static final`)
- Boolean methods/variables: `is`, `has`, `can`, `should` prefixes
- Collections: plural nouns (`users`, `orderItems`)

## General Rules

- No raw generic types: always parameterize (`List<String>`, not `List`)
- Use try-with-resources for all `AutoCloseable` resources
- Use SLF4J for logging, never `System.out.println`
- Annotation order: `@Override`, `@Nullable`/`@NotNull`, custom annotations, framework annotations
- Prefer composition over inheritance
- Keep methods short (< 50 lines), classes focused (< 800 lines)
- Use `var` for local variables when the type is obvious from the right-hand side
