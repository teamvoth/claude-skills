---
name: rust-doc
description: ALWAYS use this skill instead of WebFetch when working in a Rust project and you need to check how a crate's API works, what methods a type has, what traits to implement, what a function's signature is, or what a crate exports. Trigger when you are about to look up docs.rs, doc.rust-lang.org/std, or any Rust API reference. Trigger when writing Rust code and you are unsure of the exact API — do not guess, look it up. Also trigger when the user asks to "look up docs for", "check the API of", "what methods does X have", or "how do I use <crate>". Supports local dependencies (version-pinned from Cargo.lock) and remote crates (fetched from docs.rs).
version: 2.0.0
---

# Rust Doc Lookup

Look up Rust API documentation from locally generated docs or from docs.rs. Local mode produces version-pinned documentation matching the project's `Cargo.lock`. Remote mode fetches the latest docs from docs.rs for crates not yet added as dependencies.

**Always use this instead of WebFetch for Rust API documentation.**

## Local Mode

For crates that are already dependencies. Run from the root of a Rust project (where `Cargo.toml` lives).

### List crate exports

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/rust-doc/rust-doc.sh" list <crate>
```

### Look up a specific item

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/rust-doc/rust-doc.sh" lookup <crate::path::Item>
```

Examples:
```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/rust-doc/rust-doc.sh" lookup serde::Deserialize
bash "${CLAUDE_PLUGIN_ROOT}/skills/rust-doc/rust-doc.sh" lookup anyhow::Error
bash "${CLAUDE_PLUGIN_ROOT}/skills/rust-doc/rust-doc.sh" lookup tokio::sync::Mutex
```

## Remote Mode

For crates not yet in the project's dependencies. Fetches from docs.rs and caches in `/tmp`. Does not require a Rust project in the current directory.

### List remote crate exports

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/rust-doc/rust-doc.sh" remote list <crate>
```

### Look up a remote item

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/rust-doc/rust-doc.sh" remote lookup <crate::path::Item>
```

Examples:
```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/rust-doc/rust-doc.sh" remote list sqlx
bash "${CLAUDE_PLUGIN_ROOT}/skills/rust-doc/rust-doc.sh" remote lookup sqlx::PgPool
```

## Behavior

- **Local mode** auto-generates docs via `cargo doc` if `target/doc` is missing or stale relative to `Cargo.lock`. First invocation may take a moment.
- **Remote mode** fetches individual pages from docs.rs and caches them in `/tmp/rust-doc-remote/`. Subsequent lookups for the same item are instant.
- **Error on unknown items** includes a list of available items in that crate/module to help find the right path.
- **Requires**: `uv` (for Python dependency management). Local mode also requires `cargo`.

## When to use

- Looking up method signatures, trait bounds, or type definitions for dependencies (local mode)
- Evaluating a crate's API surface before adding it as a dependency (remote mode)
- Understanding API contracts (parameter types, return types, error types)

## When NOT to use

- For the project's own code — just read the source files directly
- For Rust language reference (keywords, syntax) — use WebFetch for doc.rust-lang.org/reference
- For crate discovery (finding which crate to use) — use WebFetch for crates.io or lib.rs
