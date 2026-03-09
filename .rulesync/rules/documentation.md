---
root: false
targets: ["claudecode"]
description: "Documentation rules: AsciiDoc, Markdown, Mermaid diagrams, continuous documentation"
globs: ["**/*"]
---

# Documentation

## Philosophy

Documentation is a continuous process, not an afterthought. Write and update docs alongside code changes.

## Formats

- **AsciiDoc** — preferred for technical documentation with complex structure (tables, includes, cross-references, conditional content)
- **Markdown** — READMEs, simple docs, GitHub-rendered content
- Choose one format per document; do not mix

## Diagrams

Use **Mermaid** for all diagrams embedded in documentation:

- **Sequence diagrams** — API flows, service interactions
- **Class diagrams** — domain models, type hierarchies
- **ER diagrams** — database schemas, entity relationships
- **Flowcharts** — decision logic, process flows
- **C4 diagrams** — system context, container, component views

Keep diagrams close to the code they describe. Update them when the code changes.

## API Documentation

- Every public API must have documentation
- Include: endpoint, method, request/response schema, error codes, examples
- Use OpenAPI/Swagger for REST APIs
- Generate docs from code annotations where possible

## Architecture Decision Records (ADR)

For significant architectural decisions:

- Title: short description of the decision
- Status: proposed / accepted / deprecated / superseded
- Context: what problem prompted this decision
- Decision: what was decided and why
- Consequences: trade-offs and implications

## Documentation Structure

Organize documentation following this hierarchy:

1. **Overview** — what the system does, high-level architecture
2. **Concepts** — domain terminology, key abstractions
3. **Guides** — how to set up, develop, deploy
4. **API Reference** — detailed endpoint/class/function documentation

## Best Practices

- Keep docs close to code (same repository when possible)
- Update docs when changing related code — treat stale docs as bugs
- Cross-reference related documents
- Code examples must be tested or extracted from real, working code
- Use consistent terminology throughout all documentation
- Write for the reader: assume they know the language but not the codebase
