---
name: documentation-mermaid
description: "Mermaid diagrams: sequence, class, ER, flowchart, C4, state diagrams"
targets: ["claudecode"]
claudecode:
  model: haiku
---

# Mermaid Diagrams

## Sequence Diagrams

```mermaid
sequenceDiagram
    participant C as Client
    participant A as API Gateway
    participant S as UserService
    participant D as Database

    C->>A: POST /api/users
    A->>S: createUser(request)
    S->>D: INSERT INTO users
    D-->>S: User entity
    S-->>A: UserResponse
    A-->>C: 201 Created
```

Key syntax:

- `participant` — declare actors (with optional alias)
- `->>` — solid arrow (synchronous call)
- `-->>` — dashed arrow (response)
- `--)` — async message (no arrowhead)

Control flow:

```mermaid
sequenceDiagram
    alt valid credentials
        S->>D: findByEmail(email)
        D-->>S: User
    else invalid credentials
        S-->>C: 401 Unauthorized
    end

    loop retry 3 times
        S->>D: save(entity)
    end

    opt with caching
        S->>Cache: get(key)
    end

    note over S,D: Transaction boundary
    note right of C: Client-side note
```

## Class Diagrams

```mermaid
classDiagram
    class UserService {
        -UserRepository repository
        -PasswordEncoder encoder
        +findById(id: Long) User?
        +create(request: CreateUserRequest) User
        #validate(user: User) Boolean
    }

    class UserRepository {
        <<interface>>
        +findByIdOrNull(id: Long) User?
        +save(user: User) User
    }

    UserService --> UserRepository : depends on
    UserService ..|> Auditable : implements
    User *-- Address : contains
    User o-- Role : has many
```

Visibility modifiers:

- `+` public
- `-` private
- `#` protected
- `~` package/internal

Relationships:

- `-->` dependency
- `..>` realization
- `*--` composition (strong ownership)
- `o--` aggregation (weak ownership)
- `<|--` inheritance

## ER Diagrams

```mermaid
erDiagram
    USER ||--o{ ORDER : places
    USER {
        bigint id PK
        varchar email UK
        varchar name
        timestamp created_at
    }
    ORDER ||--|{ ORDER_ITEM : contains
    ORDER {
        bigint id PK
        bigint user_id FK
        varchar status
        decimal total_amount
    }
    ORDER_ITEM }o--|| PRODUCT : references
    PRODUCT {
        bigint id PK
        varchar name
        decimal price
    }
```

Relationship notation:

- `||--||` one-to-one
- `||--o{` one-to-zero-or-many
- `||--|{` one-to-one-or-many
- `}o--o{` many-to-many

## Flowcharts

```mermaid
flowchart TD
    A[Start Request] --> B{Authenticated?}
    B -->|Yes| C{Authorized?}
    B -->|No| D[Return 401]
    C -->|Yes| E[Process Request]
    C -->|No| F[Return 403]
    E --> G{Success?}
    G -->|Yes| H[Return 200]
    G -->|No| I[Return 500]
```

Node shapes:

- `[text]` — rectangle
- `(text)` — rounded rectangle
- `{text}` — diamond (decision)
- `((text))` — circle
- `>text]` — flag
- `[(text)]` — cylinder (database)

Arrow types:

- `-->` solid arrow
- `-.->` dotted arrow
- `==>` thick arrow
- `-- text -->` arrow with label

Subgraphs:

```mermaid
flowchart LR
    subgraph API Layer
        A[Controller]
    end
    subgraph Business Layer
        B[Service]
    end
    subgraph Data Layer
        C[Repository]
        D[(Database)]
    end
    A --> B --> C --> D
```

## State Diagrams

```mermaid
stateDiagram-v2
    [*] --> Draft
    Draft --> Pending: submit()
    Pending --> Approved: approve()
    Pending --> Rejected: reject()
    Rejected --> Draft: revise()
    Approved --> Published: publish()
    Published --> Archived: archive()
    Archived --> [*]

    state Pending {
        [*] --> UnderReview
        UnderReview --> NeedsChanges: requestChanges()
        NeedsChanges --> UnderReview: resubmit()
        UnderReview --> [*]
    }
```

## C4 Diagrams

```mermaid
C4Context
    title System Context Diagram
    Person(user, "User", "Application end user")
    System(app, "Web Application", "Main application")
    System_Ext(email, "Email Service", "Sends notifications")
    System_Ext(payment, "Payment Gateway", "Processes payments")

    Rel(user, app, "Uses", "HTTPS")
    Rel(app, email, "Sends emails", "SMTP")
    Rel(app, payment, "Processes payments", "HTTPS/REST")
```

C4 levels:

- `C4Context` — system context (highest level)
- `C4Container` — containers within a system
- `C4Component` — components within a container

## Gantt Charts

```mermaid
gantt
    title Project Timeline
    dateFormat YYYY-MM-DD
    section Backend
        API Design        :a1, 2025-01-01, 5d
        Implementation    :a2, after a1, 10d
        Testing           :a3, after a2, 5d
    section Frontend
        UI Design         :b1, 2025-01-01, 5d
        Implementation    :b2, after b1, 10d
    section Integration
        E2E Testing       :c1, after a3, 5d
```

## Best Practices

- Keep diagrams focused: max 10-15 entities per diagram
- Use meaningful labels on relationships
- Break complex diagrams into multiple smaller ones
- Use consistent naming (PascalCase for classes, camelCase for methods)
- Add titles to diagrams for context
- Use aliases for long participant names in sequence diagrams
- Group related elements with subgraphs in flowcharts

## Integration

In Markdown:

````markdown
```mermaid
flowchart TD
    A --> B
```
````

In AsciiDoc (with Kroki):

```asciidoc
[mermaid]
....
flowchart TD
    A --> B
....
```

## Common Documentation Patterns

- API request flow → sequence diagram
- Domain model → class diagram
- Database schema → ER diagram
- Request processing pipeline → flowchart
- Entity lifecycle → state diagram
- System architecture → C4 diagram
- Project planning → Gantt chart
