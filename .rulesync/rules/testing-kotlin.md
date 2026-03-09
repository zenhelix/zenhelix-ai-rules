---
root: false
targets: ["claudecode"]
description: "Kotlin testing: JUnit 5, MockK, coroutine testing, Kotest, coverage"
globs: ["*.kt", "*.kts"]
---

# Kotlin Testing

## Stack

- **JUnit 5** — test framework
- **MockK** — mocking library (preferred over Mockito for Kotlin)
- **AssertJ** or **kotlin.test** — assertions
- **Kotest** — optional, for property-based testing and matchers
- **JaCoCo** — code coverage (minimum 80%)

## Test Naming

Use backtick-enclosed descriptive names:

```kotlin
@Test
fun `should return user when email exists`() { ... }

@Test
fun `should throw exception when email is blank`() { ... }
```

## Test Organization

Use `@Nested` inner classes to group related tests:

```kotlin
class UserServiceTest {

    @Nested
    inner class `create user` {
        @Test
        fun `should create user with valid data`() { ... }

        @Test
        fun `should reject blank email`() { ... }
    }

    @Nested
    inner class `find user` {
        @Test
        fun `should return null when not found`() { ... }
    }
}
```

## MockK Usage

```kotlin
private val userRepository = mockk<UserRepository>()
private val userService = UserService(userRepository)

@Test
fun `should save user`() {
    val user = User(name = "Alice", email = "alice@example.com")
    every { userRepository.save(any()) } returns user

    val result = userService.create(user)

    assertThat(result).isEqualTo(user)
    verify(exactly = 1) { userRepository.save(user) }
}
```

- Use `mockk()` to create mocks
- Use `every { }` / `returns` for stubbing
- Use `verify { }` to assert interactions
- Use `slot<T>()` to capture arguments
- Use `coEvery` / `coVerify` for suspending functions

## Coroutine Testing

Use `runTest` from `kotlinx-coroutines-test`:

```kotlin
@Test
fun `should fetch data asynchronously`() = runTest {
    coEvery { repository.fetchData() } returns testData

    val result = service.getData()

    assertThat(result).isEqualTo(testData)
    coVerify { repository.fetchData() }
}
```

## Test Fixtures

Create reusable test data with factory objects:

```kotlin
object TestUsers {
    fun alice() = User(id = 1, name = "Alice", email = "alice@example.com")
    fun bob() = User(id = 2, name = "Bob", email = "bob@example.com")
    fun withEmail(email: String) = alice().copy(email = email)
}
```

## Parameterized Tests

```kotlin
@ParameterizedTest
@CsvSource("alice@example.com,true", "invalid,false", ",false")
fun `should validate email`(email: String?, expected: Boolean) {
    assertThat(EmailValidator.isValid(email)).isEqualTo(expected)
}

@ParameterizedTest
@MethodSource("invalidInputs")
fun `should reject invalid input`(input: String) { ... }

companion object {
    @JvmStatic
    fun invalidInputs() = listOf("", " ", "  \t  ")
}
```

## Coverage Verification

```bash
# Run tests with coverage
./gradlew test jacocoTestReport

# Verify minimum coverage
./gradlew jacocoTestCoverageVerification
```

Configure minimum thresholds in the build script:

```kotlin
tasks.jacocoTestCoverageVerification {
    violationRules {
        rule {
            limit {
                minimum = BigDecimal("0.80")
            }
        }
    }
}
```
