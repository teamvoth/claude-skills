---
name: ubiquitous-language
description: Bootstraps, audits, and refactors the project's shared domain glossary (CONTEXT.md) independent of any specific feature work. Use to extract terminology from an existing codebase that lacks a glossary, to audit an existing glossary for stale or duplicate terms, to reconcile vocabulary drift between code and docs, or to split a glossary across bounded contexts. For feature-time language refinement, use /grill-with-docs instead — this skill is for deliberate domain-modeling work, not feature interviews. Triggers on "bootstrap the glossary", "audit CONTEXT.md", "extract domain language", "ubiquitous language", "clean up the terminology", or "reconcile the docs with the code".
version: 1.0.0
---

# Ubiquitous Language

Your job is to establish and maintain the project's **ubiquitous language** (Eric Evans, *Domain-Driven Design*): a single vocabulary shared by the code, the developers, and the domain experts, written down in `CONTEXT.md` so it can be referenced, grepped, and challenged.

This is the glossary-lifecycle skill. It is deliberately **not** a feature interview — for that, use [grill-with-docs](../grill-with-docs/SKILL.md), which folds language refinement into requirements grilling. Use this skill when language work *is* the work.

## When this skill is the right fit

- **Bootstrap.** The codebase has no `CONTEXT.md`. You need to extract a starting glossary from the code, schema, and the user's head.
- **Audit.** A `CONTEXT.md` exists but has gone stale, accumulated duplicates, or drifted from the code.
- **Reconcile.** A term in the code (a type, a column, a route segment) means something different from the term in the glossary, or the same concept has two names across modules.
- **Split.** The project has grown into multiple bounded contexts and a single glossary is no longer coherent — terms mean different things in different subsystems.
- **Onboard a new context.** A new subsystem needs its own `CONTEXT.md` and you want to seed it from related code.

If the user is describing a feature they want to build, this is the wrong skill — hand off to `/grill-with-docs`.

## Operating modes

Open with a single `AskUserQuestion` to confirm the mode and scope before doing any work. Options: **Bootstrap**, **Audit**, **Reconcile**, **Split**, **Onboard a new context**. Also ask what scope they have in mind (whole repo, one directory, one bounded context).

The mechanics below differ by mode; the discipline is the same.

### Bootstrap (no CONTEXT.md exists yet)

1. **Sweep the code for candidate terms.** Read the schema (`schema.prisma`, migrations, models, types), the top-level domain directory names, and the most-imported types. Build a candidate list of nouns and a few verb phrases (the relationships).
2. **Cluster and dedupe.** Group synonyms; flag near-duplicates for the user to resolve.
3. **Draft definitions.** One or two sentences per term, in the team's voice, referencing the code (file path or type name) where possible. Mark definitions you are unsure about — do not invent confident definitions for terms you only half-understand.
4. **Interview the user on the unsure ones.** Use `AskUserQuestion` in small batches (1–4 terms per round). Quote the candidate definition; ask whether it's right, wrong, or needs sharpening.
5. **Choose a location.** Repo root for small projects; per-bounded-context for monorepos. Confirm with the user before writing.
6. **Write `CONTEXT.md`.** Use the format below.

### Audit (CONTEXT.md exists)

1. **Read it end-to-end.** Then grep the codebase for each defined term. For each entry, classify:
   - **Live** — used in code, definition matches reality.
   - **Drifted** — used in code, but the code has evolved and the definition is now wrong or incomplete.
   - **Orphaned** — defined in the glossary, no longer present in the code.
   - **Duplicated** — same concept defined under two terms, or two concepts collapsed under one term.
2. **Also grep for terms in the code that are *not* in the glossary.** Especially domain-shaped nouns in types, table names, and route segments. These are the silent gaps.
3. **Report the classification to the user** as a compact summary before editing anything. Then `AskUserQuestion` to decide which Drifted entries to rewrite, which Orphaned ones to remove vs. keep as historical, and how to resolve Duplicates.
4. **Apply the edits.** Show the diff (or describe it) before saving.

### Reconcile (code ↔ glossary mismatch)

1. **Name the mismatch precisely.** "The glossary defines X as Y, but the code uses X to mean Z" or "the code has a type `Pitch` with no glossary entry."
2. **Decide which side moves.** Sometimes the glossary is right and the code should be renamed; sometimes the code reflects a real shift and the glossary should be updated. This is the user's call — surface the tradeoff, don't decide unilaterally.
3. **If the code moves**, do not silently rename across the codebase from this skill. Update the glossary, note the proposed rename, and hand off to a feature/refactor branch.
4. **If the glossary moves**, edit `CONTEXT.md` and note the change clearly enough that someone reading the diff understands *why* the definition shifted.

### Split (one glossary → many)

1. **Identify the bounded contexts.** Usually they map to top-level domain directories or independently deployable subsystems. Confirm the split with the user before moving anything.
2. **For each term, assign it to one or more contexts.** Terms that mean the same thing across contexts can be shared (a `Shared.md` or kept at the root). Terms that mean different things in different contexts get duplicated entries, one per context, with the context name in the entry so the difference is explicit.
3. **Move each context's terms to a CONTEXT.md inside that context's directory.** Keep a thin root `CONTEXT.md` that lists the bounded contexts and points to their glossaries.

### Onboard a new context

Same as Bootstrap, but scoped to one subdirectory, and with awareness of terms already defined elsewhere in the repo. If a term in the new context conflicts with a term in another context, add a disambiguator (qualified term, e.g., `Billing.Invoice` vs. `Accounting.Invoice`) rather than overloading.

## CONTEXT.md format

Keep it readable. A flat, alphabetical list works for small projects; group by concept area once it grows past ~30 entries.

```markdown
# CONTEXT — <project or bounded context name>

The shared vocabulary used by this codebase. If you use one of these words, you mean this. If you mean something else, pick a different word.

## <Concept area, optional>

### <Term>

<One or two sentences. Plain language. Reference the code where useful.>

- Code: `path/to/file.ts` (`TypeName`)
- Related: [[Other Term]], [[Another Term]]
- Note: <only if there's a non-obvious constraint or history>
```

Linking with `[[Other Term]]` is for navigation and to make orphans visible — broken links are a useful audit signal.

## Style rules

- **One word, one meaning. One meaning, one word.** If you find two terms for the same concept, pick one and retire the other. If one term means two things, split it.
- **Definitions are in the team's voice, not yours.** Use the language the user has been using in conversation. Sharpen it, don't replace it.
- **Reference code, but don't paste code.** A path and type name is enough; the code is the source of truth, the glossary is the index.
- **Mark uncertainty.** If you are not sure about a definition, write `(TBD — confirm with team)` rather than guessing confidently. This is a hard rule — confident-sounding speculation in a glossary poisons every downstream conversation.

## Ending

After applying changes, summarize in plain text what was added, changed, and removed. Then one `AskUserQuestion`:

- "Are the glossary changes accurate?"
- Options: "Yes, ship them" / "Edit further before saving" / "Discard the changes"

Only after confirmation is the work done.

## What not to do

- Don't run this skill mid-feature-interview. That's `/grill-with-docs`. Running both in parallel was the inefficiency that caused them to merge in the first place.
- Don't rename code from this skill. The glossary is the deliverable; code renames are a separate, reviewable change.
- Don't invent terms the team isn't using. The glossary documents reality; it doesn't impose vocabulary.
- Don't let the glossary become a thesaurus. Synonyms are a smell — resolve them, don't list them.
