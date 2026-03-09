---
name: gradle-plugins
description: "Gradle plugin development: convention plugins, published plugins, testing, composite builds"
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Gradle Plugin Development

## Convention Plugins in build-logic

Convention plugins standardize build configuration across modules.

### Project Structure

```
project-root/
├── build-logic/
│   ├── settings.gradle.kts
│   ├── build.gradle.kts
│   └── src/main/kotlin/
│       ├── kotlin-jvm-conventions.gradle.kts
│       ├── spring-boot-conventions.gradle.kts
│       └── test-conventions.gradle.kts
├── settings.gradle.kts          # includeBuild("build-logic")
├── module-a/
│   └── build.gradle.kts         # plugins { id("kotlin-jvm-conventions") }
└── module-b/
    └── build.gradle.kts
```

### build-logic/settings.gradle.kts

```kotlin
dependencyResolutionManagement {
    versionCatalogs {
        create("libs") {
            from(files("../gradle/libs.versions.toml"))
        }
    }
}

rootProject.name = "build-logic"
```

### build-logic/build.gradle.kts

```kotlin
plugins {
    `kotlin-dsl`
}

repositories {
    gradlePluginPortal()
    mavenCentral()
}

dependencies {
    implementation(libs.kotlin.gradle.plugin)
    implementation(libs.spring.boot.gradle.plugin)
    implementation(libs.detekt.gradle.plugin)
}
```

### Convention Plugin Example

`build-logic/src/main/kotlin/kotlin-jvm-conventions.gradle.kts`:

```kotlin
plugins {
    kotlin("jvm")
}

kotlin {
    jvmToolchain(21)
    compilerOptions {
        freeCompilerArgs.addAll(
            "-Xjsr305=strict",
            "-Xcontext-receivers"
        )
        allWarningsAsErrors.set(true)
    }
}

tasks.withType<Test>().configureEach {
    useJUnitPlatform()
    jvmArgs("-XX:+EnableDynamicAgentLoading")
}
```

### Including in settings.gradle.kts

```kotlin
pluginManagement {
    includeBuild("build-logic")
}
```

## Published Plugin Development

### Plugin Class

```kotlin
package com.example.gradle

import org.gradle.api.Plugin
import org.gradle.api.Project

class MyPlugin : Plugin<Project> {

    override fun apply(project: Project) {
        val extension = project.extensions.create(
            "myPlugin",
            MyPluginExtension::class.java
        )

        project.afterEvaluate {
            project.tasks.register("myTask", MyTask::class.java) { task ->
                task.inputFile.set(extension.configFile)
                task.outputDir.set(extension.outputDirectory)
                task.group = "my-plugin"
                task.description = "Runs my custom task"
            }
        }
    }
}
```

### Extension Class

```kotlin
package com.example.gradle

import org.gradle.api.file.DirectoryProperty
import org.gradle.api.file.RegularFileProperty
import org.gradle.api.model.ObjectFactory
import org.gradle.api.provider.ListProperty
import org.gradle.api.provider.Property
import javax.inject.Inject

abstract class MyPluginExtension @Inject constructor(objects: ObjectFactory) {

    val enabled: Property<Boolean> = objects.property(Boolean::class.java)
        .convention(true)

    val configFile: RegularFileProperty = objects.fileProperty()

    val outputDirectory: DirectoryProperty = objects.directoryProperty()

    val excludePatterns: ListProperty<String> = objects.listProperty(String::class.java)
        .convention(emptyList())
}
```

### Custom Task

```kotlin
package com.example.gradle

import org.gradle.api.DefaultTask
import org.gradle.api.file.DirectoryProperty
import org.gradle.api.file.RegularFileProperty
import org.gradle.api.tasks.CacheableTask
import org.gradle.api.tasks.InputFile
import org.gradle.api.tasks.OutputDirectory
import org.gradle.api.tasks.PathSensitive
import org.gradle.api.tasks.PathSensitivity
import org.gradle.api.tasks.TaskAction

@CacheableTask
abstract class MyTask : DefaultTask() {

    @get:InputFile
    @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val inputFile: RegularFileProperty

    @get:OutputDirectory
    abstract val outputDir: DirectoryProperty

    @TaskAction
    fun execute() {
        val input = inputFile.get().asFile
        val output = outputDir.get().asDir

        logger.lifecycle("Processing ${input.name}")
        // Task implementation
    }
}
```

### Provider API

Use lazy properties to enable configuration avoidance:

```kotlin
// Property<T> — single value
val version: Property<String> = objects.property(String::class.java)

// ListProperty<T> — list of values
val tags: ListProperty<String> = objects.listProperty(String::class.java)

// MapProperty<K, V> — key-value pairs
val metadata: MapProperty<String, String> = objects.mapProperty(
    String::class.java, String::class.java
)

// RegularFileProperty — single file
val configFile: RegularFileProperty = objects.fileProperty()

// DirectoryProperty — directory
val outputDir: DirectoryProperty = objects.directoryProperty()

// ConfigurableFileCollection — multiple files
val sourceFiles: ConfigurableFileCollection = objects.fileCollection()
```

Wire properties with `.set()` and `.get()`:

```kotlin
task.inputFile.set(extension.configFile)
val value = extension.enabled.getOrElse(true)
```

## Testing

### Unit Tests with ProjectBuilder

```kotlin
import org.gradle.testfixtures.ProjectBuilder
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.*

class MyPluginTest {

    @Test
    fun `plugin registers myTask`() {
        val project = ProjectBuilder.builder().build()
        project.plugins.apply("com.example.my-plugin")

        assertNotNull(project.tasks.findByName("myTask"))
    }

    @Test
    fun `plugin creates extension with defaults`() {
        val project = ProjectBuilder.builder().build()
        project.plugins.apply("com.example.my-plugin")

        val extension = project.extensions.getByType(MyPluginExtension::class.java)
        assertTrue(extension.enabled.get())
    }
}
```

### Functional Tests with GradleRunner (TestKit)

```kotlin
import org.gradle.testkit.runner.GradleRunner
import org.gradle.testkit.runner.TaskOutcome
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir
import java.io.File
import org.junit.jupiter.api.Assertions.*

class MyPluginFunctionalTest {

    @TempDir
    lateinit var projectDir: File

    @BeforeEach
    fun setup() {
        projectDir.resolve("settings.gradle.kts").writeText("")
        projectDir.resolve("build.gradle.kts").writeText("""
            plugins {
                id("com.example.my-plugin")
            }

            myPlugin {
                enabled.set(true)
                configFile.set(file("config.yml"))
                outputDirectory.set(layout.buildDirectory.dir("generated"))
            }
        """.trimIndent())
        projectDir.resolve("config.yml").writeText("key: value")
    }

    @Test
    fun `myTask completes successfully`() {
        val result = GradleRunner.create()
            .withProjectDir(projectDir)
            .withArguments("myTask", "--stacktrace")
            .withPluginClasspath()
            .build()

        assertEquals(TaskOutcome.SUCCESS, result.task(":myTask")?.outcome)
    }

    @Test
    fun `myTask is cacheable`() {
        val runner = GradleRunner.create()
            .withProjectDir(projectDir)
            .withArguments("myTask", "--build-cache")
            .withPluginClasspath()

        runner.build()
        val result = runner.build()

        assertEquals(TaskOutcome.UP_TO_DATE, result.task(":myTask")?.outcome)
    }
}
```

## Publishing

### Plugin build.gradle.kts

```kotlin
plugins {
    `java-gradle-plugin`
    `maven-publish`
    id("com.gradle.plugin-publish") version "1.3.0"
}

gradlePlugin {
    website.set("https://github.com/example/my-plugin")
    vcsUrl.set("https://github.com/example/my-plugin")

    plugins {
        create("myPlugin") {
            id = "com.example.my-plugin"
            displayName = "My Plugin"
            description = "Does something useful"
            tags.set(listOf("kotlin", "code-generation"))
            implementationClass = "com.example.gradle.MyPlugin"
        }
    }
}
```

Plugin marker artifact is auto-generated by `java-gradle-plugin`.

## Composite Builds for Local Development

During development, test a plugin locally without publishing:

```kotlin
// consumer/settings.gradle.kts
pluginManagement {
    includeBuild("../my-plugin")
}
```

This substitutes the plugin dependency with the local project.

## Version Catalog Access in Plugins

Access the version catalog inside convention plugins:

```kotlin
// build-logic/src/main/kotlin/kotlin-jvm-conventions.gradle.kts
val libs = the<org.gradle.accessors.dm.LibrariesForLibs>()

dependencies {
    implementation(libs.kotlinx.coroutines.core)
    testImplementation(libs.bundles.testing)
}
```

Requires `kotlin-dsl` plugin in build-logic to generate catalog accessors.

## Common Convention Plugin Patterns

- **kotlin-jvm-conventions** — Kotlin JVM toolchain, compiler options, test config
- **spring-boot-conventions** — Spring Boot plugin, dependency management
- **test-conventions** — JUnit 5, test containers, coverage
- **quality-conventions** — Detekt, Spotless, Diktat
- **publishing-conventions** — Maven publish, signing, Nexus staging
