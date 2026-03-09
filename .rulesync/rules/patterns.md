---
root: false
targets: ["claudecode"]
description: "Universal patterns: repository, service layer, DTO mapping, API response envelope"
globs: ["**/*"]
---

# Common Patterns

## Repository Pattern

Encapsulate data access behind a consistent interface:
- Define standard operations: findAll, findById, create, update, delete
- Concrete implementations handle storage details (database, API, file, cache)
- Business logic depends on the abstract interface, not the storage mechanism
- Enables easy swapping of data sources and simplifies testing with mocks

## Service Layer

- Encapsulate all business logic in service classes
- Services orchestrate repositories and other services
- Define transaction boundaries at the service layer
- Services accept and return domain objects or DTOs, never entities directly
- Keep services stateless

## DTO Mapping

- Separate domain/entity objects from transport/API objects
- Use dedicated mapper classes or functions for conversion
- Never expose internal entity structure through APIs
- Map at the boundary: controller layer for REST, message handler for messaging
- Validate DTOs before mapping to domain objects

## API Response Envelope

Use a consistent format for all API responses:

```
{
  "success": true/false,
  "data": { ... } or null,
  "error": { "code": "...", "message": "..." } or null,
  "meta": { "total": 100, "page": 1, "limit": 20 } // for paginated responses
}
```

- Always include a success/status indicator
- Data payload is null on error
- Error field is null on success
- Include pagination metadata when returning collections

## Skeleton Projects

When starting a new service or module:

1. Search for battle-tested skeleton projects or templates
2. Evaluate options for security, extensibility, and relevance
3. Clone the best match as a foundation
4. Iterate within the proven structure rather than building from scratch
