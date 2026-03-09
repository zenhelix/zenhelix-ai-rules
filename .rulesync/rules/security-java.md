---
root: false
targets: ["claudecode"]
description: "Java security: Spring Security, Bean Validation, parameterized queries, BCrypt, JWT, CORS"
globs: ["*.java"]
---

# Java Security

## Spring Security

- Define security as `SecurityFilterChain` beans, not by extending deprecated `WebSecurityConfigurerAdapter`
- Use stateless sessions for REST APIs: `SessionCreationPolicy.STATELESS`
- Apply method-level security with `@PreAuthorize` / `@Secured` where appropriate
- Deny by default, explicitly permit public endpoints

```java
@Bean
public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    return http
        .csrf(csrf -> csrf.disable()) // disable only for stateless APIs
        .sessionManagement(session -> session.sessionCreationPolicy(STATELESS))
        .authorizeHttpRequests(auth -> auth
            .requestMatchers("/api/public/**").permitAll()
            .anyRequest().authenticated()
        )
        .build();
}
```

## Bean Validation

- Use `@Valid` on controller method parameters to trigger validation
- Standard annotations: `@NotNull`, `@NotBlank`, `@Size`, `@Email`, `@Min`, `@Max`, `@Pattern`
- Create custom validators for complex business rules
- Validate at the API boundary, not deep in service logic

```java
public record CreateUserRequest(
    @NotBlank @Size(max = 100) String name,
    @NotBlank @Email String email,
    @NotNull @Min(0) @Max(150) Integer age
) {}
```

## SQL Injection Prevention

- ALWAYS use parameterized queries
- JPA: named parameters with `@Param`
- Criteria API: type-safe query construction
- NEVER concatenate user input into SQL strings
- jOOQ DSL is inherently safe from injection

```java
// WRONG
@Query("SELECT u FROM User u WHERE u.name = '" + name + "'")

// CORRECT
@Query("SELECT u FROM User u WHERE u.name = :name")
List<User> findByName(@Param("name") String name);
```

## Password Hashing

- Use BCrypt with strength 12 or higher
- Never store plaintext passwords
- Use `PasswordEncoder` interface for abstraction

```java
@Bean
public PasswordEncoder passwordEncoder() {
    return new BCryptPasswordEncoder(12);
}
```

## JWT Security

- Store JWT signing secrets in environment variables, never in code or config files
- Use short expiration times (15-30 minutes for access tokens)
- Validate token signature, expiration, and issuer on every request
- Use refresh tokens for session extension
- Invalidate tokens on logout (use a blocklist or short-lived tokens)

## CORS Configuration

- Never use wildcard (`*`) origins with credentials
- Explicitly list allowed origins per environment
- Restrict allowed methods and headers to what is needed

```java
@Bean
public CorsConfigurationSource corsConfigurationSource() {
    var config = new CorsConfiguration();
    config.setAllowedOrigins(List.of("https://app.example.com"));
    config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE"));
    config.setAllowCredentials(true);
    var source = new UrlBasedCorsConfigurationSource();
    source.registerCorsConfiguration("/api/**", config);
    return source;
}
```

## Rate Limiting

- Use Bucket4j or Resilience4j for rate limiting
- Apply rate limits to all public endpoints
- Return `429 Too Many Requests` with `Retry-After` header
- Different limits for authenticated vs. anonymous users

## Secret Management

- Load all secrets from environment variables or a secret manager
- Validate required secrets at startup (fail fast)
- Use Spring profiles for environment-specific configuration
- Never commit `.env` files or `application-local.yml` with real secrets

## Dependency Security

- Use OWASP Dependency-Check Gradle plugin
- Run dependency checks in CI pipeline
- Update vulnerable dependencies promptly
- Review transitive dependencies

## Logging Security

- Never log passwords, tokens, API keys, or PII
- Use parameterized logging to prevent log injection
- Sanitize user input before including in log messages
- Log security events (failed logins, authorization failures)
