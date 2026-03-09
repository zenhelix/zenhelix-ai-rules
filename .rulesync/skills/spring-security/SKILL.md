---
name: spring-security
description: "Spring Security: authentication, JWT, OAuth2, RBAC, method security, CORS"
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Spring Security

Comprehensive guide for Spring Security: authentication flows, JWT, OAuth2, role-based access control, method security, and testing.

## SecurityFilterChain Configuration

### Kotlin

```kotlin
@Configuration
@EnableWebSecurity
@EnableMethodSecurity
class SecurityConfig(
    private val jwtAuthFilter: JwtAuthenticationFilter,
    private val userDetailsService: CustomUserDetailsService
) {

    @Bean
    fun securityFilterChain(http: HttpSecurity): SecurityFilterChain =
        http
            .csrf { it.disable() } // Stateless API — no CSRF needed
            .sessionManagement { it.sessionCreationPolicy(SessionCreationPolicy.STATELESS) }
            .authorizeHttpRequests { auth ->
                auth
                    .requestMatchers("/api/v1/auth/**").permitAll()
                    .requestMatchers("/actuator/health").permitAll()
                    .requestMatchers("/api/v1/admin/**").hasRole("ADMIN")
                    .requestMatchers(HttpMethod.GET, "/api/v1/products/**").permitAll()
                    .requestMatchers("/api/v1/**").authenticated()
                    .anyRequest().denyAll()
            }
            .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter::class.java)
            .exceptionHandling { ex ->
                ex.authenticationEntryPoint(HttpStatusEntryPoint(HttpStatus.UNAUTHORIZED))
                ex.accessDeniedHandler { _, response, _ ->
                    response.status = HttpStatus.FORBIDDEN.value()
                }
            }
            .headers { headers ->
                headers.frameOptions { it.deny() }
                headers.contentSecurityPolicy { it.policyDirectives("default-src 'self'") }
            }
            .build()

    @Bean
    fun passwordEncoder(): PasswordEncoder = BCryptPasswordEncoder(12)

    @Bean
    fun authenticationManager(config: AuthenticationConfiguration): AuthenticationManager =
        config.authenticationManager
}
```

### Java

```java
@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

    private final JwtAuthenticationFilter jwtAuthFilter;

    public SecurityConfig(JwtAuthenticationFilter jwtAuthFilter) {
        this.jwtAuthFilter = jwtAuthFilter;
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        return http
            .csrf(csrf -> csrf.disable())
            .sessionManagement(session ->
                session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/v1/auth/**").permitAll()
                .requestMatchers("/actuator/health").permitAll()
                .requestMatchers("/api/v1/admin/**").hasRole("ADMIN")
                .requestMatchers(HttpMethod.GET, "/api/v1/products/**").permitAll()
                .requestMatchers("/api/v1/**").authenticated()
                .anyRequest().denyAll())
            .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class)
            .exceptionHandling(ex -> {
                ex.authenticationEntryPoint(new HttpStatusEntryPoint(HttpStatus.UNAUTHORIZED));
                ex.accessDeniedHandler((request, response, accessDeniedException) ->
                    response.setStatus(HttpStatus.FORBIDDEN.value()));
            })
            .build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder(12);
    }

    @Bean
    public AuthenticationManager authenticationManager(
            AuthenticationConfiguration config) throws Exception {
        return config.getAuthenticationManager();
    }
}
```

## JWT Authentication

### JWT Token Service

#### Kotlin

```kotlin
@Service
class JwtTokenService(
    @Value("\${app.jwt.secret}") private val secret: String,
    @Value("\${app.jwt.expiration:3600}") private val expirationSeconds: Long,
    @Value("\${app.jwt.refresh-expiration:604800}") private val refreshExpirationSeconds: Long
) {

    private val key: SecretKey = Keys.hmacShaKeyFor(secret.toByteArray())

    fun generateAccessToken(user: UserDetails): String =
        generateToken(user, Duration.ofSeconds(expirationSeconds))

    fun generateRefreshToken(user: UserDetails): String =
        generateToken(user, Duration.ofSeconds(refreshExpirationSeconds))

    private fun generateToken(user: UserDetails, expiration: Duration): String {
        val now = Instant.now()
        return Jwts.builder()
            .subject(user.username)
            .claim("roles", user.authorities.map { it.authority })
            .issuedAt(Date.from(now))
            .expiration(Date.from(now.plus(expiration)))
            .signWith(key)
            .compact()
    }

    fun extractUsername(token: String): String? =
        try {
            parseClaims(token).subject
        } catch (ex: JwtException) {
            null
        }

    fun isTokenValid(token: String, userDetails: UserDetails): Boolean =
        try {
            val claims = parseClaims(token)
            claims.subject == userDetails.username && !claims.expiration.before(Date())
        } catch (ex: JwtException) {
            false
        }

    private fun parseClaims(token: String): Claims =
        Jwts.parser()
            .verifyWith(key)
            .build()
            .parseSignedClaims(token)
            .payload
}
```

### JWT Authentication Filter

#### Kotlin

```kotlin
@Component
class JwtAuthenticationFilter(
    private val jwtTokenService: JwtTokenService,
    private val userDetailsService: CustomUserDetailsService
) : OncePerRequestFilter() {

    override fun doFilterInternal(
        request: HttpServletRequest,
        response: HttpServletResponse,
        filterChain: FilterChain
    ) {
        val token = extractToken(request)
        if (token != null) {
            val username = jwtTokenService.extractUsername(token)
            if (username != null && SecurityContextHolder.getContext().authentication == null) {
                val userDetails = userDetailsService.loadUserByUsername(username)
                if (jwtTokenService.isTokenValid(token, userDetails)) {
                    val auth = UsernamePasswordAuthenticationToken(
                        userDetails, null, userDetails.authorities
                    )
                    auth.details = WebAuthenticationDetailsSource().buildDetails(request)
                    SecurityContextHolder.getContext().authentication = auth
                }
            }
        }
        filterChain.doFilter(request, response)
    }

    private fun extractToken(request: HttpServletRequest): String? {
        val header = request.getHeader(HttpHeaders.AUTHORIZATION)
        return if (header != null && header.startsWith("Bearer ")) {
            header.substring(7)
        } else null
    }
}
```

### Auth Controller

```kotlin
@RestController
@RequestMapping("/api/v1/auth")
class AuthController(
    private val authenticationManager: AuthenticationManager,
    private val jwtTokenService: JwtTokenService,
    private val userDetailsService: CustomUserDetailsService
) {

    @PostMapping("/login")
    fun login(@Valid @RequestBody request: LoginRequest): ResponseEntity<TokenResponse> {
        authenticationManager.authenticate(
            UsernamePasswordAuthenticationToken(request.username, request.password)
        )
        val userDetails = userDetailsService.loadUserByUsername(request.username)
        val accessToken = jwtTokenService.generateAccessToken(userDetails)
        val refreshToken = jwtTokenService.generateRefreshToken(userDetails)
        return ResponseEntity.ok(TokenResponse(accessToken, refreshToken))
    }

    @PostMapping("/refresh")
    fun refresh(@Valid @RequestBody request: RefreshTokenRequest): ResponseEntity<TokenResponse> {
        val username = jwtTokenService.extractUsername(request.refreshToken)
            ?: throw BadCredentialsException("Invalid refresh token")
        val userDetails = userDetailsService.loadUserByUsername(username)
        if (!jwtTokenService.isTokenValid(request.refreshToken, userDetails)) {
            throw BadCredentialsException("Expired refresh token")
        }
        val accessToken = jwtTokenService.generateAccessToken(userDetails)
        return ResponseEntity.ok(TokenResponse(accessToken, request.refreshToken))
    }
}

data class LoginRequest(
    @field:NotBlank val username: String,
    @field:NotBlank val password: String
)

data class RefreshTokenRequest(
    @field:NotBlank val refreshToken: String
)

data class TokenResponse(
    val accessToken: String,
    val refreshToken: String,
    val tokenType: String = "Bearer"
)
```

## Custom UserDetailsService

### Kotlin

```kotlin
@Service
class CustomUserDetailsService(
    private val userRepository: UserRepository
) : UserDetailsService {

    override fun loadUserByUsername(username: String): UserDetails {
        val user = userRepository.findByUsername(username)
            ?: throw UsernameNotFoundException("User not found: $username")
        return User.builder()
            .username(user.username)
            .password(user.passwordHash)
            .authorities(user.roles.map { SimpleGrantedAuthority("ROLE_${it.name}") })
            .accountLocked(!user.active)
            .build()
    }
}
```

### Java

```java
@Service
public class CustomUserDetailsService implements UserDetailsService {

    private final UserRepository userRepository;

    public CustomUserDetailsService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @Override
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        AppUser user = userRepository.findByUsername(username)
            .orElseThrow(() -> new UsernameNotFoundException("User not found: " + username));
        return User.builder()
            .username(user.getUsername())
            .password(user.getPasswordHash())
            .authorities(user.getRoles().stream()
                .map(role -> new SimpleGrantedAuthority("ROLE_" + role.getName()))
                .toList())
            .accountLocked(!user.isActive())
            .build();
    }
}
```

## OAuth2 Resource Server

```kotlin
@Configuration
@EnableWebSecurity
class OAuth2ResourceServerConfig {

    @Bean
    fun securityFilterChain(http: HttpSecurity): SecurityFilterChain =
        http
            .oauth2ResourceServer { oauth2 ->
                oauth2.jwt { jwt ->
                    jwt.jwtAuthenticationConverter(jwtAuthenticationConverter())
                }
            }
            .authorizeHttpRequests { auth ->
                auth
                    .requestMatchers("/api/v1/public/**").permitAll()
                    .requestMatchers("/api/v1/**").authenticated()
            }
            .build()

    private fun jwtAuthenticationConverter(): JwtAuthenticationConverter {
        val grantedAuthoritiesConverter = JwtGrantedAuthoritiesConverter().apply {
            setAuthoritiesClaimName("roles")
            setAuthorityPrefix("ROLE_")
        }
        return JwtAuthenticationConverter().apply {
            setJwtGrantedAuthoritiesConverter(grantedAuthoritiesConverter)
        }
    }
}
```

```yaml
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: https://auth.example.com
          # or jwk-set-uri: https://auth.example.com/.well-known/jwks.json
```

## Method-Level Security

```kotlin
@Service
class OrderService(
    private val orderRepository: OrderRepository
) {

    @PreAuthorize("hasRole('ADMIN') or #customerId == authentication.name")
    fun findByCustomer(customerId: String): List<Order> =
        orderRepository.findByCustomerId(customerId)

    @PreAuthorize("hasAnyRole('ADMIN', 'MANAGER')")
    fun updateStatus(orderId: Long, status: OrderStatus): Order =
        orderRepository.findById(orderId)
            .orElseThrow { EntityNotFoundException("Order", orderId) }
            .let { order ->
                orderRepository.save(order.copy(status = status))
            }

    @PreAuthorize("hasRole('ADMIN')")
    fun deleteAll(): Unit = orderRepository.deleteAll()

    @PostAuthorize("returnObject.customerId == authentication.name or hasRole('ADMIN')")
    fun findById(id: Long): Order =
        orderRepository.findById(id)
            .orElseThrow { EntityNotFoundException("Order", id) }
}
```

## CORS with Security

```kotlin
@Bean
fun securityFilterChain(http: HttpSecurity): SecurityFilterChain =
    http
        .cors { it.configurationSource(corsConfigurationSource()) }
        .csrf { it.disable() }
        // ... rest of config
        .build()

@Bean
fun corsConfigurationSource(): CorsConfigurationSource {
    val config = CorsConfiguration().apply {
        allowedOrigins = listOf("https://app.example.com")
        allowedMethods = listOf("GET", "POST", "PUT", "DELETE", "PATCH")
        allowedHeaders = listOf("*")
        allowCredentials = true
        maxAge = 3600
    }
    return UrlBasedCorsConfigurationSource().apply {
        registerCorsConfiguration("/api/**", config)
    }
}
```

## CSRF Guidelines

| Scenario                    | CSRF                                  |
|-----------------------------|---------------------------------------|
| Stateless REST API with JWT | Disable                               |
| Session-based web app       | Enable (default)                      |
| SPA with cookie auth        | Enable with CookieCsrfTokenRepository |
| Public read-only API        | Disable                               |

## Testing Security

### Kotlin

```kotlin
@WebMvcTest(OrderController::class)
class OrderControllerSecurityTest {

    @Autowired
    private lateinit var mockMvc: MockMvc

    @MockkBean
    private lateinit var orderService: OrderService

    @Test
    @WithMockUser(roles = ["USER"])
    fun `authenticated user can access orders`() {
        every { orderService.findAll(any()) } returns Page.empty()

        mockMvc.get("/api/v1/orders")
            .andExpect { status { isOk() } }
    }

    @Test
    fun `unauthenticated user gets 401`() {
        mockMvc.get("/api/v1/orders")
            .andExpect { status { isUnauthorized() } }
    }

    @Test
    @WithMockUser(roles = ["USER"])
    fun `regular user cannot access admin endpoint`() {
        mockMvc.get("/api/v1/admin/users")
            .andExpect { status { isForbidden() } }
    }

    @Test
    @WithMockUser(roles = ["ADMIN"])
    fun `admin can access admin endpoint`() {
        mockMvc.get("/api/v1/admin/users")
            .andExpect { status { isOk() } }
    }

    @Test
    fun `login returns JWT tokens`() {
        mockMvc.post("/api/v1/auth/login") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"username": "user@test.com", "password": "password123"}"""
        }.andExpect {
            status { isOk() }
            jsonPath("$.accessToken") { isNotEmpty() }
            jsonPath("$.refreshToken") { isNotEmpty() }
            jsonPath("$.tokenType") { value("Bearer") }
        }
    }
}
```

### Java

```java
@WebMvcTest(OrderController.class)
class OrderControllerSecurityTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private OrderService orderService;

    @Test
    @WithMockUser(roles = "USER")
    void authenticatedUserCanAccessOrders() throws Exception {
        when(orderService.findAll(any())).thenReturn(Page.empty());

        mockMvc.perform(get("/api/v1/orders"))
            .andExpect(status().isOk());
    }

    @Test
    void unauthenticatedUserGets401() throws Exception {
        mockMvc.perform(get("/api/v1/orders"))
            .andExpect(status().isUnauthorized());
    }

    @Test
    @WithMockUser(roles = "ADMIN")
    void adminCanAccessAdminEndpoint() throws Exception {
        mockMvc.perform(get("/api/v1/admin/users"))
            .andExpect(status().isOk());
    }
}
```

## Security Headers Configuration

```yaml
server:
  servlet:
    session:
      cookie:
        http-only: true
        secure: true
        same-site: strict
```

## Best Practices

1. **Use BCrypt with strength 12+** for password hashing
2. **Never disable CSRF** for session-based applications
3. **Disable CSRF** for stateless JWT APIs
4. **Validate JWT signatures** — never trust unsigned tokens
5. **Set short access token expiry** (15-60 minutes) with refresh tokens
6. **Use @PreAuthorize** for fine-grained access control
7. **Deny by default** — use `.anyRequest().denyAll()` as catch-all
8. **Never return security details** in error messages to clients
9. **Use HTTPS only** — configure `server.ssl` or terminate at load balancer
10. **Rotate secrets** — store JWT secret in vault, not in code
11. **Test security rules** — write tests for both allowed and denied access
12. **Use Security headers** — Content-Security-Policy, X-Frame-Options, HSTS
