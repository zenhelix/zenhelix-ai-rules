---
name: gradle-config
description: "Gradle configuration: multi-module, dependency management, version catalogs, build cache, optimization"
targets: ["claudecode"]
claudecode:
  model: haiku
---

# Gradle Configuration

## settings.gradle.kts

```kotlin
rootProject.name = "my-project"

pluginManagement {
    includeBuild("build-logic")
    repositories {
        gradlePluginPortal()
        mavenCentral()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        mavenCentral()
        maven { url = uri("https://repo.example.com/releases") }
    }
}

include(
    ":core",
    ":api",
    ":service",
    ":infrastructure:persistence",
    ":infrastructure:messaging",
)
```

## Version Catalogs (libs.versions.toml)

Located at `gradle/libs.versions.toml`:

```toml
[versions]
kotlin = "2.0.21"
spring-boot = "3.4.1"
spring-dependency-management = "1.1.7"
kotlinx-coroutines = "1.9.0"
jackson = "2.18.2"
kotest = "5.9.1"
mockk = "1.13.13"

[libraries]
kotlinx-coroutines-core = { module = "org.jetbrains.kotlinx:kotlinx-coroutines-core", version.ref = "kotlinx-coroutines" }
kotlinx-coroutines-reactor = { module = "org.jetbrains.kotlinx:kotlinx-coroutines-reactor", version.ref = "kotlinx-coroutines" }
jackson-module-kotlin = { module = "com.fasterxml.jackson.module:jackson-module-kotlin", version.ref = "jackson" }
kotest-runner-junit5 = { module = "io.kotest:kotest-runner-junit5", version.ref = "kotest" }
kotest-assertions-core = { module = "io.kotest:kotest-assertions-core", version.ref = "kotest" }
mockk = { module = "io.mockk:mockk", version.ref = "mockk" }

[bundles]
kotest = ["kotest-runner-junit5", "kotest-assertions-core"]
kotlinx-coroutines = ["kotlinx-coroutines-core", "kotlinx-coroutines-reactor"]

[plugins]
kotlin-jvm = { id = "org.jetbrains.kotlin.jvm", version.ref = "kotlin" }
kotlin-spring = { id = "org.jetbrains.kotlin.plugin.spring", version.ref = "kotlin" }
spring-boot = { id = "org.springframework.boot", version.ref = "spring-boot" }
spring-dependency-management = { id = "io.spring.dependency-management", version.ref = "spring-dependency-management" }
```

Usage in build.gradle.kts:

```kotlin
dependencies {
    implementation(libs.kotlinx.coroutines.core)
    implementation(libs.bundles.kotlinx.coroutines)
    testImplementation(libs.bundles.kotest)
    testImplementation(libs.mockk)
}
```

## Dependency Configurations

```kotlin
dependencies {
    // Compile and runtime, NOT exposed to consumers
    implementation(libs.jackson.module.kotlin)

    // Compile and runtime, EXPOSED to consumers (use sparingly)
    api(libs.kotlinx.coroutines.core)

    // Compile only (annotations, provided by runtime)
    compileOnly("jakarta.servlet:jakarta.servlet-api")

    // Runtime only (JDBC drivers, logging backends)
    runtimeOnly("org.postgresql:postgresql")

    // Test dependencies
    testImplementation(libs.bundles.kotest)
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")

    // Annotation processing
    kapt(libs.mapstruct.processor)

    // BOM/Platform (version alignment)
    implementation(platform(libs.spring.boot.bom))
    implementation(platform("org.testcontainers:testcontainers-bom:1.20.4"))
}
```

## Multi-Module Configuration

### Root build.gradle.kts

```kotlin
plugins {
    alias(libs.plugins.kotlin.jvm) apply false
    alias(libs.plugins.spring.boot) apply false
}
```

### Shared Configuration (prefer convention plugins over allprojects/subprojects)

```kotlin
// AVOID this pattern:
subprojects {
    apply(plugin = "kotlin")
}

// PREFER convention plugins:
// Each module applies: plugins { id("kotlin-jvm-conventions") }
```

### Module build.gradle.kts

```kotlin
plugins {
    id("kotlin-jvm-conventions")
    id("spring-boot-conventions")
}

dependencies {
    implementation(project(":core"))
    implementation(libs.spring.boot.starter.web)
}
```

## Build Cache

### gradle.properties

```properties
# Enable parallel execution
org.gradle.parallel=true

# Enable build cache
org.gradle.caching=true

# Enable configuration cache
org.gradle.configuration-cache=true

# Daemon settings
org.gradle.daemon=true
org.gradle.jvmargs=-Xmx4g -XX:+UseG1GC -XX:+HeapDumpOnOutOfMemoryError

# File system watching
org.gradle.vfs.watch=true
```

### Remote Build Cache

```kotlin
// settings.gradle.kts
buildCache {
    local {
        isEnabled = true
        directory = File(rootDir, ".gradle/build-cache")
    }
    remote<HttpBuildCache> {
        url = uri("https://cache.example.com/cache/")
        isPush = System.getenv("CI") != null
        credentials {
            username = System.getenv("CACHE_USER") ?: ""
            password = System.getenv("CACHE_PASS") ?: ""
        }
    }
}
```

Debug cache misses:

```bash
./gradlew myTask --build-cache -Dorg.gradle.caching.debug=true
```

## Configuration Avoidance

```kotlin
// WRONG: eagerly creates the task
tasks.create("myTask") { }

// CORRECT: lazily registers, only created when needed
tasks.register("myTask") { }

// WRONG: eagerly configures all Test tasks
tasks.withType<Test> { }

// CORRECT: lazily configures when tasks are realized
tasks.withType<Test>().configureEach { }
```

## Dependency Locking

```kotlin
dependencyLocking {
    lockAllConfigurations()
}
```

Generate lock files:

```bash
./gradlew dependencies --write-locks
```

## Custom Configurations

```kotlin
val integrationTestImplementation by configurations.creating {
    extendsFrom(configurations.testImplementation.get())
}

val integrationTestRuntimeOnly by configurations.creating {
    extendsFrom(configurations.testRuntimeOnly.get())
}
```

## Repository Configuration

```kotlin
repositories {
    mavenCentral()
    maven {
        url = uri("https://repo.example.com/releases")
        credentials {
            username = findProperty("repoUser") as String? ?: ""
            password = findProperty("repoPassword") as String? ?: ""
        }
        content {
            includeGroup("com.example")
        }
    }
    maven {
        url = uri("https://repo.spring.io/milestone")
        content {
            includeGroupByRegex("org\\.springframework.*")
        }
    }
}
```

## Useful Gradle Commands

```bash
# Dependency tree
./gradlew :module:dependencies --configuration runtimeClasspath

# Dependency insight
./gradlew :module:dependencyInsight --dependency spring-core

# Build scan
./gradlew build --scan

# Refresh dependencies
./gradlew build --refresh-dependencies

# Configuration cache report
./gradlew build --configuration-cache
```
