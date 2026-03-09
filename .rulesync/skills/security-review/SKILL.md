---
name: security-review
description: "Security review: OWASP Top 10, Spring Security audit, dependency scanning, secrets detection"
targets: ["claudecode"]
claudecode:
  model: opus
  allowed-tools: ["Read", "Grep", "Glob", "Bash"]
---

# Security Review

## When to Activate

Trigger a security review when changes involve:

- Authentication or authorization logic
- User input handling (forms, query params, request bodies)
- New API endpoints or route changes
- Secrets, tokens, API keys, or credentials
- Payment processing or financial data
- File upload or download functionality
- Database queries or schema changes
- Third-party integrations
- CORS or security header configuration
- Session management changes

## OWASP Top 10 Checklist for Spring Applications

### A01: Broken Access Control

- Verify `@PreAuthorize` / `@Secured` on all sensitive endpoints
- Check that users cannot access other users' data (IDOR)
- Verify role hierarchy is correctly configured
- Ensure default-deny: `anyRequest().authenticated()` as the last rule
- Test that disabled accounts cannot authenticate

```kotlin
// VERIFY: proper authorization checks
@PreAuthorize("hasRole('ADMIN') or #userId == authentication.principal.id")
fun getUserProfile(userId: Long): UserProfile

// VERIFY: no direct object reference without ownership check
fun getOrder(orderId: Long): Order {
    val order = orderRepository.findByIdOrNull(orderId)
        ?: throw NotFoundException("Order not found")
    val currentUserId = SecurityContextHolder.getContext().authentication.principal.id
    if (order.userId != currentUserId && !hasRole("ADMIN")) {
        throw ForbiddenException("Access denied")
    }
    return order
}
```

### A02: Cryptographic Failures

- Passwords stored with BCrypt (cost 12+) or Argon2id
- Sensitive data encrypted at rest
- TLS enforced for all external communications
- No sensitive data in URLs or query parameters
- No sensitive data in logs

```kotlin
// GOOD: BCrypt with strength 12
@Bean
fun passwordEncoder(): PasswordEncoder = BCryptPasswordEncoder(12)

// BETTER: Argon2id
@Bean
fun passwordEncoder(): PasswordEncoder = Argon2PasswordEncoder.defaultsForSpringSecurity_v5_8()
```

### A03: Injection

#### SQL Injection

```kotlin
// VULNERABLE: string concatenation
@Query("SELECT u FROM User u WHERE u.name = '" + name + "'")  // NEVER DO THIS

// SAFE: parameterized queries
@Query("SELECT u FROM User u WHERE u.name = :name")
fun findByName(@Param("name") name: String): User?

// SAFE: JPA method queries
fun findByEmailAndStatus(email: String, status: UserStatus): User?

// SAFE: jOOQ (parameterized by default)
dsl.selectFrom(USERS).where(USERS.EMAIL.eq(email)).fetchOne()

// SAFE: JDBC with PreparedStatement
connection.prepareStatement("SELECT * FROM users WHERE id = ?").use { stmt ->
    stmt.setLong(1, id)
    stmt.executeQuery()
}
```

#### LDAP Injection

```kotlin
// Sanitize LDAP special characters: *, (, ), \, NUL
fun sanitizeLdapInput(input: String): String =
    input.replace("\\", "\\\\")
        .replace("*", "\\*")
        .replace("(", "\\(")
        .replace(")", "\\)")
        .replace("\u0000", "")
```

### A04: Insecure Design

- Review business logic for abuse scenarios
- Validate all state transitions
- Implement rate limiting on sensitive operations
- Add account lockout after failed login attempts

### A05: Security Misconfiguration

```kotlin
// VERIFY: security headers configured
@Bean
fun securityFilterChain(http: HttpSecurity): SecurityFilterChain = http
    .headers {
        it.contentSecurityPolicy { csp ->
            csp.policyDirectives("default-src 'self'; script-src 'self'; style-src 'self'")
        }
        it.frameOptions { fo -> fo.deny() }
        it.httpStrictTransportSecurity { hsts ->
            hsts.includeSubDomains(true)
            hsts.maxAgeInSeconds(31536000)
        }
        it.contentTypeOptions { } // X-Content-Type-Options: nosniff
    }
    .build()
```

```yaml
# VERIFY: no debug/dev settings in production
spring:
  jpa:
    show-sql: false          # NEVER true in production
    open-in-view: false      # Disable OSIV
  devtools:
    restart:
      enabled: false         # Disable in production
server:
  error:
    include-stacktrace: never
    include-message: never   # Do not expose error details
```

### A06: Vulnerable and Outdated Components

- Run OWASP Dependency-Check regularly
- Configure Gradle plugin:

```kotlin
// build.gradle.kts
plugins {
    id("org.owasp.dependencycheck") version "10.0.3"
}

dependencyCheck {
    failBuildOnCVSS = 7.0f
    suppressionFile = "config/owasp-suppressions.xml"
    analyzers.assemblyEnabled = false
}
```

- Run: `./gradlew dependencyCheckAnalyze`
- Also consider: Snyk (`snyk test --all-projects`)

### A07: Identification and Authentication Failures

```kotlin
// VERIFY: proper authentication configuration
@Bean
fun securityFilterChain(http: HttpSecurity): SecurityFilterChain = http
    .sessionManagement {
        it.sessionCreationPolicy(SessionCreationPolicy.STATELESS) // for JWT APIs
    }
    .build()

// VERIFY: JWT token validation
class JwtTokenProvider(
    @Value("\${jwt.secret}") private val secret: String,
    @Value("\${jwt.expiration-ms}") private val expirationMs: Long,
) {
    // Token must be validated: signature, expiration, issuer
    fun validateToken(token: String): Boolean {
        try {
            val claims = Jwts.parserBuilder()
                .setSigningKey(Keys.hmacShaKeyFor(secret.toByteArray()))
                .build()
                .parseClaimsJws(token)
            return !claims.body.expiration.before(Date())
        } catch (ex: JwtException) {
            logger.warn("Invalid JWT token: ${ex.message}")
            return false
        }
    }
}
```

### A08: Software and Data Integrity Failures

- Verify CI/CD pipeline integrity
- Check that dependencies are from trusted sources
- Use Gradle dependency verification: `gradle/verification-metadata.xml`
- Sign release artifacts

### A09: Security Logging and Monitoring Failures

```kotlin
// LOG security-relevant events
logger.info("User login successful: userId={}", userId)
logger.warn("Failed login attempt: email={}, ip={}", email, remoteAddr)
logger.warn("Unauthorized access attempt: userId={}, resource={}", userId, resource)
logger.info("Password changed: userId={}", userId)
logger.warn("Account locked: userId={}, reason={}", userId, reason)

// NEVER log sensitive data
logger.info("User authenticated: email={}", email)  // OK
logger.info("User authenticated: password={}", password)  // NEVER
logger.info("Payment processed: cardNumber={}", cardNumber)  // NEVER
logger.info("Token issued: token={}", token)  // NEVER
```

### A10: Server-Side Request Forgery (SSRF)

```kotlin
// VALIDATE URLs before making requests
fun validateUrl(url: String): URI {
    val uri = URI(url)
    val host = InetAddress.getByName(uri.host)
    require(!host.isLoopbackAddress) { "Loopback addresses not allowed" }
    require(!host.isSiteLocalAddress) { "Private addresses not allowed" }
    require(!host.isLinkLocalAddress) { "Link-local addresses not allowed" }
    require(uri.scheme in listOf("http", "https")) { "Only HTTP(S) allowed" }
    return uri
}
```

## Secrets Management

### Environment Variables

```kotlin
// Kotlin — reading secrets
val dbPassword = System.getenv("DB_PASSWORD")
    ?: throw IllegalStateException("DB_PASSWORD environment variable is required")

// Spring — @Value with env fallback
@Value("\${database.password:\${DB_PASSWORD:}}")
private lateinit var dbPassword: String

// Spring — @ConfigurationProperties (preferred)
@ConfigurationProperties(prefix = "app.security")
data class SecurityProperties(
    val jwtSecret: String,
    val jwtExpirationMs: Long = 3600000,
    val bcryptStrength: Int = 12,
)
```

### Detecting Hardcoded Secrets

Search patterns to audit:

```
# API keys and tokens
password\s*=\s*["'][^"']+["']
secret\s*=\s*["'][^"']+["']
api[_-]?key\s*=\s*["'][^"']+["']
token\s*=\s*["'][^"']+["']

# Connection strings with credentials
jdbc:.*password=
mongodb://.*:.*@

# AWS/Cloud keys
AKIA[0-9A-Z]{16}
```

Files to check:

- `application.yml` / `application.properties`
- `docker-compose.yml`
- `*.env` files
- Test configuration files
- CI/CD pipeline definitions

## Input Validation

```kotlin
// Bean Validation on request DTOs
data class CreateUserRequest(
    @field:NotBlank(message = "Name is required")
    @field:Size(min = 2, max = 100, message = "Name must be 2-100 characters")
    @field:Pattern(regexp = "^[a-zA-Z\\s-']+$", message = "Name contains invalid characters")
    val name: String,

    @field:NotBlank
    @field:Email(message = "Invalid email format")
    @field:Size(max = 255)
    val email: String,

    @field:NotBlank
    @field:Size(min = 8, max = 128)
    val password: String,
)

// Custom validator
@Target(AnnotationTarget.FIELD)
@Constraint(validatedBy = [SafeHtmlValidator::class])
annotation class SafeHtml(
    val message: String = "Contains unsafe HTML",
    val groups: Array<KClass<*>> = [],
    val payload: Array<KClass<out Payload>> = [],
)

class SafeHtmlValidator : ConstraintValidator<SafeHtml, String> {
    override fun isValid(value: String?, context: ConstraintValidatorContext): Boolean {
        if (value == null) return true
        return !value.contains(Regex("<script|javascript:|on\\w+=", RegexOption.IGNORE_CASE))
    }
}
```

## XSS Prevention

```kotlin
// Content-Type headers prevent MIME sniffing
// Spring Security sets X-Content-Type-Options: nosniff by default

// CSP header blocks inline scripts
.headers {
    it.contentSecurityPolicy { csp ->
        csp.policyDirectives("default-src 'self'; script-src 'self'; object-src 'none'")
    }
}

// HTML sanitization if accepting rich text
fun sanitizeHtml(input: String): String =
    Jsoup.clean(input, Safelist.basic())
```

## CSRF Configuration

```kotlin
// Stateless JWT API: CSRF can be disabled
http.csrf { it.disable() }

// Session-based application: CSRF MUST be enabled
http.csrf { csrf ->
    csrf.csrfTokenRepository(CookieCsrfTokenRepository.withHttpOnlyFalse())
    csrf.csrfTokenRequestHandler(CsrfTokenRequestAttributeHandler())
}
```

## CORS Configuration

```kotlin
@Bean
fun corsConfigurationSource(): CorsConfigurationSource {
    val config = CorsConfiguration().apply {
        allowedOrigins = listOf("https://app.example.com") // NEVER use "*" with credentials
        allowedMethods = listOf("GET", "POST", "PUT", "DELETE", "PATCH")
        allowedHeaders = listOf("Authorization", "Content-Type")
        allowCredentials = true
        maxAge = 3600
    }
    val source = UrlBasedCorsConfigurationSource()
    source.registerCorsConfiguration("/api/**", config)
    return source
}
```

## Dependency Scanning

### OWASP Dependency-Check (Gradle)

```kotlin
plugins {
    id("org.owasp.dependencycheck") version "10.0.3"
}

dependencyCheck {
    failBuildOnCVSS = 7.0f
    formats = listOf("HTML", "JSON")
    outputDirectory = "${layout.buildDirectory.get()}/reports/dependency-check"
    suppressionFile = "config/owasp-suppressions.xml"
}
```

### Snyk Integration

```bash
snyk test --all-projects --severity-threshold=high
snyk monitor --all-projects
```

## Pre-Deployment Security Checklist

- [ ] No hardcoded secrets in source code or configuration
- [ ] All endpoints have proper authentication and authorization
- [ ] Input validation on all user-facing parameters
- [ ] SQL injection prevention (parameterized queries only)
- [ ] XSS prevention (CSP headers, output encoding)
- [ ] CSRF protection enabled for session-based auth
- [ ] CORS configured with specific origins (no wildcards with credentials)
- [ ] Security headers configured (HSTS, CSP, X-Frame-Options)
- [ ] Passwords stored with BCrypt(12+) or Argon2id
- [ ] JWT tokens validated (signature, expiration, issuer)
- [ ] Rate limiting on authentication and sensitive endpoints
- [ ] No sensitive data in logs (passwords, tokens, PII)
- [ ] OWASP Dependency-Check passes (no CVE >= 7.0)
- [ ] Error responses do not leak internal details
- [ ] TLS enforced for all external communication
- [ ] Actuator endpoints secured or disabled in production
- [ ] Debug/dev features disabled in production
- [ ] File upload validated (type, size, content)
- [ ] Account lockout after repeated failed logins
- [ ] Audit logging for security-relevant events
