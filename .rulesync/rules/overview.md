---
root: true
targets: ["claudecode"]
description: "Project overview: Kotlin/Java backend development with Spring, PostgreSQL, Gradle"
globs: ["**/*"]
---

# Project Overview

## Stack

- Languages: Kotlin, Java (JVM ecosystem)
- Framework: Spring Boot (Web, WebFlux, Data JPA, Data R2DBC, Security, Batch, Cloud, Integration)
- Database: PostgreSQL with Flyway/Liquibase migrations, jOOQ, JPA/Hibernate
- Build: Gradle with Kotlin DSL
- Testing: JUnit 5, MockK, Mockito, TestContainers, Spring Boot Test
- Documentation: AsciiDoc, Markdown, Mermaid diagrams

## Principles
- Organize code by feature/domain, not by file type
- Prefer composition over inheritance
- Immutability by default
- Write self-documenting code with clear naming
- Use dependency injection for testability
- Handle errors at every layer
- Follow single responsibility principle
- Continuous documentation as part of development workflow

## Architecture

- Layered: Controller → Service → Repository
- Clean separation of concerns
- Domain-driven design where appropriate
- API-first approach for external interfaces
