---
name: documentation-asciidoc
description: "AsciiDoc: syntax, document structure, cross-references, includes, callouts, tables"
targets: ["claudecode"]
claudecode:
  model: haiku
---

# AsciiDoc Documentation

## Document Header

Every AsciiDoc document starts with a header block:

```asciidoc
= Document Title
Author Name <author@example.com>
:revnumber: 1.0
:revdate: 2025-01-15
:toc: left
:toclevels: 3
:sectnums:
:sectnumlevels: 4
:source-highlighter: highlight.js
:icons: font
:imagesdir: images
:experimental:
```

Key header attributes:

- `:toc:` — table of contents placement (left, right, preamble, macro)
- `:sectnums:` — auto-number sections
- `:source-highlighter:` — syntax highlighting engine (highlight.js, rouge, coderay)
- `:icons: font` — use Font Awesome icons for admonitions
- `:experimental:` — enable UI macros (kbd, btn, menu)

## Section Hierarchy

```asciidoc
= Document Title (Level 0)
== Section (Level 1)
=== Subsection (Level 2)
==== Sub-subsection (Level 3)
===== Paragraph-level (Level 4)
```

Rules:

- Only one Level 0 title per document
- Do not skip levels (e.g., == directly to ====)
- Use meaningful, descriptive section titles

## Text Formatting

```asciidoc
*bold text*
_italic text_
`monospace text`
*_bold italic_*
[.underline]#underlined text#
[.line-through]#strikethrough#
^superscript^
~subscript~
```

## Code Blocks with Callouts

```asciidoc
[source,kotlin]
----
class UserService(
    private val repository: UserRepository // <1>
) {
    fun findById(id: Long): User? = // <2>
        repository.findByIdOrNull(id)
}
----
<1> Constructor injection of the repository
<2> Returns nullable User if not found
```

Callout rules:

- Number callouts sequentially: `<1>`, `<2>`, `<3>`
- Place callout markers at end of the relevant line
- List explanations immediately after the code block

## Includes

```asciidoc
\include::chapter01.adoc[]
\include::shared/header.adoc[leveloffset=+1]
\include::example.kt[tags=service-method]
```

Include with tags (in source file):

```kotlin
// tag::service-method[]
fun findAll(): List<User> = repository.findAll()
// end::service-method[]
```

Options:

- `leveloffset=+1` — shift section levels down by one
- `lines=5..10` — include only specific line range
- `tags=tagname` — include tagged regions
- `indent=0` — reset indentation

## Cross-References

Within the same document:

```asciidoc
[[custom-anchor]]
== My Section

See <<custom-anchor>> for details.
See <<custom-anchor,the configuration section>> for details.
```

Between documents:

```asciidoc
xref:other-file.adoc#section-id[Link text]
xref:module:page.adoc[Link text]
```

## Tables

```asciidoc
.Table caption
[cols="1,2,3a", options="header"]
|===
| Column 1 | Column 2 | Column 3

| Cell 1
| Cell 2
| Cell 3 with AsciiDoc content

* Item A
* Item B
|===
```

Column specifiers:

- `1,2,3` — proportional widths
- `a` suffix — AsciiDoc content in cell
- `h` suffix — header-styled column
- `<`, `^`, `>` — horizontal alignment (left, center, right)
- `.^` — vertical center alignment

## Admonitions

```asciidoc
NOTE: Informational note for the reader.

TIP: Helpful suggestion or shortcut.

WARNING: Something that could cause problems.

IMPORTANT: Critical information the reader must know.

CAUTION: Action that could lead to data loss or security issue.
```

Block-style admonition:

```asciidoc
[WARNING]
====
This is a multi-paragraph warning.

It can contain any AsciiDoc content.
====
```

## Lists

Unordered:

```asciidoc
* Item 1
** Nested item
*** Deeply nested
* Item 2
```

Ordered:

```asciidoc
. First step
. Second step
.. Sub-step A
.. Sub-step B
. Third step
```

Description list:

```asciidoc
Term 1:: Definition of term 1
Term 2:: Definition of term 2
Nested term::: Nested definition
```

## Images

```asciidoc
image::architecture-diagram.png[Architecture Overview, 800]
image::logo.svg[Company Logo, 200, 200]
```

Inline image:

```asciidoc
Click the image:icons/settings.png[Settings, 16, 16] icon.
```

## Conditional Processing

```asciidoc
\ifdef::backend-html5[]
This content only appears in HTML output.
\endif::[]

\ifndef::skip-advanced[]
\include::advanced-topics.adoc[]
\endif::[]

\ifeval::[{sectnums} == true]
Sections are numbered.
\endif::[]
```

## Attributes for Reusable Values

```asciidoc
:project-name: MyApplication
:spring-boot-version: 3.3.0
:kotlin-version: 2.0.0

This guide covers {project-name} built with Spring Boot {spring-boot-version}
and Kotlin {kotlin-version}.
```

## Best Practices

- Write one sentence per line for better diffs and version control
- Use attributes for values that appear in multiple places
- Keep includes shallow (avoid deeply nested include chains)
- Use tagged regions instead of line numbers for code includes
- Place images in a dedicated `images/` directory
- Use meaningful anchor IDs rather than auto-generated ones
- Prefer block-style admonitions for multi-line content
- Use `[%collapsible]` for optional/advanced content
- Validate documents with asciidoctor before publishing
- Use consistent attribute naming: lowercase, hyphens between words
