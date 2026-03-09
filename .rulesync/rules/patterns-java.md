---
root: false
targets: ["claudecode"]
description: "Java patterns: repository with JPA, service layer, DTO mapping, builder, strategy, exception hierarchy"
globs: ["*.java"]
---

# Java Patterns

## JPA Repository

```java
public interface UserRepository extends JpaRepository<User, Long> {

    Optional<User> findByEmail(String email);

    @Query("SELECT u FROM User u WHERE u.active = true AND u.createdAt > :since")
    List<User> findActiveUsersSince(@Param("since") Instant since);

    // Specifications for dynamic queries
    static Specification<User> hasName(String name) {
        return (root, query, cb) -> cb.equal(root.get("name"), name);
    }

    static Specification<User> isActive() {
        return (root, query, cb) -> cb.isTrue(root.get("active"));
    }
}
```

Use specifications for composable, dynamic query construction:

```java
var users = userRepository.findAll(
    hasName("Alice").and(isActive())
);
```

## Service Layer

```java
@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    @Transactional(readOnly = true)
    public UserDto findById(Long id) {
        return userRepository.findById(id)
            .map(UserDto::fromEntity)
            .orElseThrow(() -> new NotFoundException("User not found: " + id));
    }

    @Transactional
    public UserDto create(CreateUserRequest request) {
        var user = new User(
            request.name(),
            request.email(),
            passwordEncoder.encode(request.password())
        );
        return UserDto.fromEntity(userRepository.save(user));
    }
}
```

- Annotate with `@Service`
- Use constructor injection (via `@RequiredArgsConstructor` or explicit constructor)
- Mark read operations with `@Transactional(readOnly = true)`
- Mark write operations with `@Transactional`
- Keep business logic in services, not controllers or repositories

## DTO Mapping

### Static Factory Methods (simple cases)

```java
public record UserDto(Long id, String name, String email) {

    public static UserDto fromEntity(User user) {
        return new UserDto(user.getId(), user.getName(), user.getEmail());
    }
}
```

### MapStruct (complex mappings)

```java
@Mapper(componentModel = "spring")
public interface UserMapper {
    UserDto toDto(User user);
    User toEntity(CreateUserRequest request);
}
```

- Separate domain entities from API transport objects
- Map at the controller boundary
- Never expose JPA entities directly through REST APIs

## Builder Pattern

### With Records

```java
public record SearchCriteria(
    String name,
    String email,
    Boolean active,
    Instant createdAfter
) {
    public static Builder builder() { return new Builder(); }

    public static class Builder {
        private String name;
        private String email;
        private Boolean active;
        private Instant createdAfter;

        public Builder name(String name) { this.name = name; return this; }
        public Builder email(String email) { this.email = email; return this; }
        public Builder active(Boolean active) { this.active = active; return this; }
        public Builder createdAfter(Instant createdAfter) { this.createdAfter = createdAfter; return this; }

        public SearchCriteria build() {
            return new SearchCriteria(name, email, active, createdAfter);
        }
    }
}
```

For simpler cases, use Lombok `@Builder` on records or classes.

## Strategy Pattern with Spring

```java
public interface NotificationSender {
    String type();
    void send(String recipient, String message);
}

@Component
public class EmailSender implements NotificationSender {
    public String type() { return "email"; }
    public void send(String recipient, String message) { ... }
}

@Component
public class SmsSender implements NotificationSender {
    public String type() { return "sms"; }
    public void send(String recipient, String message) { ... }
}

@Service
public class NotificationService {
    private final Map<String, NotificationSender> senders;

    public NotificationService(List<NotificationSender> senderList) {
        this.senders = senderList.stream()
            .collect(Collectors.toMap(NotificationSender::type, Function.identity()));
    }

    public void send(String type, String recipient, String message) {
        var sender = Optional.ofNullable(senders.get(type))
            .orElseThrow(() -> new IllegalArgumentException("Unknown sender type: " + type));
        sender.send(recipient, message);
    }
}
```

## Exception Hierarchy

```java
public abstract class AppException extends RuntimeException {
    private final String code;

    protected AppException(String code, String message) {
        super(message);
        this.code = code;
    }

    public String getCode() { return code; }
}

public class NotFoundException extends AppException {
    public NotFoundException(String message) {
        super("NOT_FOUND", message);
    }
}

public class ValidationException extends AppException {
    public ValidationException(String message) {
        super("VALIDATION_ERROR", message);
    }
}
```

### Global Exception Handler

```java
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(NotFoundException.class)
    public ResponseEntity<ErrorResponse> handleNotFound(NotFoundException ex) {
        return ResponseEntity.status(404)
            .body(new ErrorResponse(ex.getCode(), ex.getMessage()));
    }

    @ExceptionHandler(ValidationException.class)
    public ResponseEntity<ErrorResponse> handleValidation(ValidationException ex) {
        return ResponseEntity.status(400)
            .body(new ErrorResponse(ex.getCode(), ex.getMessage()));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleUnexpected(Exception ex) {
        log.error("Unexpected error", ex);
        return ResponseEntity.status(500)
            .body(new ErrorResponse("INTERNAL_ERROR", "An unexpected error occurred"));
    }
}
```

## Pagination

```java
@GetMapping("/users")
public Page<UserDto> listUsers(
    @RequestParam(defaultValue = "0") int page,
    @RequestParam(defaultValue = "20") int size,
    @RequestParam(defaultValue = "name") String sortBy
) {
    var pageable = PageRequest.of(page, size, Sort.by(sortBy));
    return userService.findAll(pageable);
}
```

Use Spring Data `Pageable` and `Page<T>` for consistent pagination across all list endpoints.
