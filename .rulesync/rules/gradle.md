---
root: false
targets: ["claudecode"]
description: "Gradle: Kotlin DSL, multi-module, version catalogs, convention plugins, build cache"
globs: ["*.gradle.kts", "*.gradle", "settings.gradle.kts", "buildSrc/**/*", "build-logic/**/*"]
---

# Gradle Build System

## Kotlin DSL

- Always use Kotlin DSL (`.gradle.kts` files), never Groovy
- Leverage type-safe accessors and IDE autocompletion
- Avoid `buildscript {}` block; use `plugins {}` DSL exclusively

## Dependency Management

- Use **version catalogs** (`gradle/libs.versions.toml`) for all dependency versions
- Reference dependencies as `libs.<alias>` in build scripts
- Group related versions (e.g., Spring Boot BOM, Kotlin version)
- Lock dependency versions for reproducible builds

Example `libs.versions.toml` structure:

```toml
[versions]
kotlin = "2.1.x"
spring-boot = "3.4.x"

[libraries]
spring-boot-starter-web = { module = "org.springframework.boot:spring-boot-starter-web", version.ref = "spring-boot" }

[plugins]
kotlin-jvm = { id = "org.jetbrains.kotlin.jvm", version.ref = "kotlin" }
```

## Convention Plugins

- Place shared build logic in `buildSrc/` or `build-logic/` as convention plugins
- Extract common configurations: Kotlin compiler options, test setup, code quality, publishing
- Name conventions clearly: `kotlin-library-conventions`, `spring-service-conventions`

## Multi-Module Projects

- `settings.gradle.kts` includes all modules
- Root `build.gradle.kts` for configuration shared across all subprojects
- Each module has its own `build.gradle.kts` applying relevant convention plugins
- Minimize inter-module dependencies; prefer API/implementation separation

## Build Performance

- Enable local build cache: `org.gradle.caching=true` in `gradle.properties`
- Enable configuration cache where possible
- Use `register()` instead of `create()` for task configuration avoidance
- Use providers and lazy configuration
- Parallel execution: `org.gradle.parallel=true`

## Common Plugins

```kotlin
plugins {
    kotlin("jvm")
    kotlin("plugin.spring")
    id("org.springframework.boot")
    id("io.spring.dependency-management")
}
```

## Testing Configuration

```kotlin
tasks.test {
    useJUnitPlatform()
    jvmArgs("-XX:+EnableDynamicAgentLoading")
}
```

- JaCoCo plugin for coverage reports and verification
- Configure minimum coverage thresholds in convention plugins
- Separate source sets for integration tests when needed

## Dependency Configurations

- `implementation` — internal dependency, not exposed to consumers
- `api` — dependency exposed to consumers (use sparingly)
- `testImplementation` — test-only dependency
- `runtimeOnly` — needed at runtime but not compile time (e.g., JDBC drivers)
- `annotationProcessor` / `kapt` / `ksp` — annotation processing
