---
name: rust-doc
description: Looks up Rust API documentation for crates, types, traits, and functions. ALWAYS use instead of WebFetch for docs.rs or doc.rust-lang.org. Triggers when checking method signatures, trait bounds, crate exports, or any Rust API details. Also triggers on "look up docs for", "what methods does X have", "how do I use <crate>". Do not guess Rust APIs — use this skill to look them up.
argument-hint: "[list|lookup] [remote] <crate::path::Item>"
version: 3.0.0
---

# Rust Doc Lookup

Looks up Rust API documentation from locally generated docs or from docs.rs. Local mode produces version-pinned documentation matching the project's `Cargo.lock`. Remote mode fetches the latest docs from docs.rs for crates not yet added as dependencies.

**Always use this instead of WebFetch for Rust API documentation.**

## Local Mode

For crates that are already dependencies. Run from the root of a Rust project (where `Cargo.toml` lives).

### List crate exports

```bash
bash "${CLAUDE_SKILL_DIR}/rust-doc.sh" list <crate>
```

### Look up a specific item

```bash
bash "${CLAUDE_SKILL_DIR}/rust-doc.sh" lookup <crate::path::Item>
```

Examples:
```bash
bash "${CLAUDE_SKILL_DIR}/rust-doc.sh" lookup serde::Deserialize
bash "${CLAUDE_SKILL_DIR}/rust-doc.sh" lookup anyhow::Error
bash "${CLAUDE_SKILL_DIR}/rust-doc.sh" lookup tokio::sync::Mutex
```

## Remote Mode

For crates not yet in the project's dependencies. Fetches from docs.rs and caches in `/tmp`. Does not require a Rust project in the current directory.

### List remote crate exports

```bash
bash "${CLAUDE_SKILL_DIR}/rust-doc.sh" remote list <crate>
```

### Look up a remote item

```bash
bash "${CLAUDE_SKILL_DIR}/rust-doc.sh" remote lookup <crate::path::Item>
```

Examples:
```bash
bash "${CLAUDE_SKILL_DIR}/rust-doc.sh" remote list sqlx
bash "${CLAUDE_SKILL_DIR}/rust-doc.sh" remote lookup sqlx::PgPool
```

## Behavior

- **Local mode** auto-generates docs via `cargo doc` if `target/doc` is missing or stale relative to `Cargo.lock`. First invocation may take a moment.
- **Remote mode** fetches individual pages from docs.rs and caches them in `/tmp/rust-doc-remote/`. Subsequent lookups for the same item are instant.
- **Error on unknown items** includes a list of available items in that crate/module to help find the right path.
- **Requires**: `uv` (for Python dependency management). Local mode also requires `cargo`.

## When to use

- Looking up method signatures, trait bounds, or type definitions for dependencies
- Evaluating a crate's API surface before adding it as a dependency (remote mode)
- Understanding API contracts (parameter types, return types, error types)
- Any time Rust API details are needed — do not guess, look them up

## When NOT to use

- For the project's own code — just read the source files directly
- For Rust language reference (keywords, syntax) — use WebFetch for doc.rust-lang.org/reference
- For crate discovery (finding which crate to use) — use WebFetch for crates.io or lib.rs
