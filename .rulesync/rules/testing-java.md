---
root: false
targets: ["claudecode"]
description: "Java testing: JUnit 5, Mockito, AssertJ, Spring Boot test slices, TestContainers, coverage"
globs: ["*.java"]
---

# Java Testing

## Stack

- **JUnit 5** — test framework
- **Mockito** — mocking library
- **AssertJ** — fluent assertions
- **MockMvc** — Spring MVC testing
- **TestContainers** — real database/service containers for integration tests
- **JaCoCo** — code coverage (minimum 80%)

## Test Naming

Use the pattern `methodName_scenario_expectedResult`:

```java
@Test
void createUser_validInput_returnsCreatedUser() { ... }

@Test
void createUser_blankEmail_throwsValidationException() { ... }

@Test
void findById_nonExistentId_returnsEmpty() { ... }
```

## Mockito Usage

```java
@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private UserService userService;

    @Test
    void createUser_validInput_savesAndReturns() {
        var user = new User("Alice", "alice@example.com");
        when(userRepository.save(any(User.class))).thenReturn(user);

        var result = userService.create(user);

        assertThat(result).isEqualTo(user);
        verify(userRepository, times(1)).save(user);
    }
}
```

- Use `@Mock` for dependencies, `@InjectMocks` for the system under test
- Use `@ExtendWith(MockitoExtension.class)`, not `@RunWith`
- Use `when(...).thenReturn(...)` for stubbing
- Use `verify(...)` for interaction verification
- Use `ArgumentCaptor` to capture and inspect arguments

## Spring Boot Test Slices

```java
// Controller tests — loads only web layer
@WebMvcTest(UserController.class)
class UserControllerTest {
    @Autowired private MockMvc mockMvc;
    @MockBean private UserService userService;

    @Test
    void getUser_existingId_returns200() throws Exception {
        when(userService.findById(1L)).thenReturn(Optional.of(testUser));

        mockMvc.perform(get("/api/users/1"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.name").value("Alice"));
    }
}

// Repository tests — loads JPA layer with embedded database
@DataJpaTest
class UserRepositoryTest {
    @Autowired private UserRepository repository;
    @Autowired private TestEntityManager em;

    @Test
    void findByEmail_existingEmail_returnsUser() {
        em.persistAndFlush(new User("Alice", "alice@example.com"));

        var result = repository.findByEmail("alice@example.com");

        assertThat(result).isPresent();
    }
}
```

## TestContainers Integration

```java
@SpringBootTest
@Testcontainers
class UserIntegrationTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16")
        .withDatabaseName("testdb");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }
}
```

## Test Fixtures

Use factory methods for reusable test data:

```java
class TestUsers {
    static User alice() {
        return new User(1L, "Alice", "alice@example.com");
    }

    static User bob() {
        return new User(2L, "Bob", "bob@example.com");
    }

    static User withEmail(String email) {
        return new User(null, "Test", email);
    }
}
```

## Coverage Enforcement

Configure JaCoCo in Gradle:

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

tasks.check {
    dependsOn(tasks.jacocoTestCoverageVerification)
}
```

Run: `./gradlew test jacocoTestReport jacocoTestCoverageVerification`
