#!/usr/bin/env bash
set -euo pipefail

# rust-doc.sh — Look up Rust dependency documentation from local or remote docs.
#
# Usage:
#   rust-doc.sh list <crate>                    List a local crate's exports
#   rust-doc.sh lookup <crate::path::Item>      Look up a specific local type/trait/fn
#   rust-doc.sh remote list <crate>             List exports from docs.rs
#   rust-doc.sh remote lookup <crate::path::Item>  Look up a specific item from docs.rs
#
# Local mode generates HTML docs via `cargo doc` if missing or stale.
# Remote mode fetches from docs.rs and caches in /tmp.
# Exits non-zero with an error message on failure.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTRACT_SCRIPT="$SCRIPT_DIR/extract-doc.py"

die() {
  echo "Error: $1" >&2
  exit 1
}

usage() {
  echo "Usage:" >&2
  echo "  $0 list <crate>                         List a local crate's exports" >&2
  echo "  $0 lookup <crate::path::Item>            Look up a specific local type/trait/fn" >&2
  echo "  $0 remote list <crate>                   List exports from docs.rs" >&2
  echo "  $0 remote lookup <crate::path::Item>     Look up a specific item from docs.rs" >&2
  exit 1
}

# --- Validate environment ---

[[ -f "$EXTRACT_SCRIPT" ]] || die "extract-doc.py not found at $EXTRACT_SCRIPT"
command -v uv >/dev/null 2>&1 || die "uv is required but not installed."

# --- Parse args ---

[[ $# -ge 2 ]] || usage

REMOTE=false
if [[ "$1" == "remote" ]]; then
  REMOTE=true
  shift
fi

[[ $# -ge 2 ]] || usage
MODE="$1"
TARGET="$2"

[[ "$MODE" == "list" || "$MODE" == "lookup" ]] || die "Unknown mode: $MODE. Use 'list' or 'lookup'."

# --- Remote mode: fetch from docs.rs ---

if [[ "$REMOTE" == true ]]; then
  # Extract crate name (first segment of the path)
  CRATE_NAME="${TARGET%%::*}"
  CRATE_NAME_UNDERSCORED="${CRATE_NAME//-/_}"

  # Cache mirrors local doc structure: /tmp/rust-doc-remote/<crate_underscored>/...
  CACHE_ROOT="/tmp/rust-doc-remote"
  CRATE_DIR="$CACHE_ROOT/${CRATE_NAME_UNDERSCORED}"
  mkdir -p "$CRATE_DIR"

  # Determine which page to fetch
  if [[ "$MODE" == "list" ]]; then
    URL="https://docs.rs/${CRATE_NAME}/latest/${CRATE_NAME_UNDERSCORED}/index.html"
    CACHE_FILE="$CRATE_DIR/index.html"

    if [[ ! -f "$CACHE_FILE" ]]; then
      HTTP_CODE=$(curl -sL -o "$CACHE_FILE" -w "%{http_code}" "$URL" 2>/dev/null)
      [[ "$HTTP_CODE" == "200" ]] || { rm -f "$CACHE_FILE"; die "Failed to fetch ${URL} (HTTP ${HTTP_CODE})."; }
    fi
  else
    # Parse path: crate::mod::Item -> try each prefix
    IFS='::' read -ra PARTS <<< "$TARGET"
    # Filter empty parts from :: splitting
    CLEAN_PARTS=()
    for p in "${PARTS[@]}"; do
      [[ -n "$p" ]] && CLEAN_PARTS+=("$p")
    done

    LAST_IDX=$(( ${#CLEAN_PARTS[@]} - 1 ))
    ITEM_NAME="${CLEAN_PARTS[$LAST_IDX]}"
    # Module path (parts between crate and item)
    MODULE_PATH=""
    for ((i=1; i<LAST_IDX; i++)); do
      MODULE_PATH="${MODULE_PATH}${CLEAN_PARTS[$i]}/"
    done

    ITEM_DIR="$CRATE_DIR/${MODULE_PATH}"
    mkdir -p "$ITEM_DIR"

    # Try each rustdoc prefix to find the right page
    PREFIXES=("struct" "trait" "enum" "fn" "macro" "type" "constant" "derive")
    FOUND=false
    for prefix in "${PREFIXES[@]}"; do
      URL="https://docs.rs/${CRATE_NAME}/latest/${CRATE_NAME_UNDERSCORED}/${MODULE_PATH}${prefix}.${ITEM_NAME}.html"
      CACHE_FILE="$ITEM_DIR/${prefix}.${ITEM_NAME}.html"

      if [[ -f "$CACHE_FILE" ]]; then
        FOUND=true
        break
      fi

      HTTP_CODE=$(curl -sL -o "$CACHE_FILE" -w "%{http_code}" "$URL" 2>/dev/null)
      if [[ "$HTTP_CODE" == "200" ]]; then
        FOUND=true
        break
      else
        rm -f "$CACHE_FILE"
      fi
    done

    if [[ "$FOUND" != true ]]; then
      # Try fetching the index to list available items
      INDEX_URL="https://docs.rs/${CRATE_NAME}/latest/${CRATE_NAME_UNDERSCORED}/${MODULE_PATH}index.html"
      INDEX_CACHE="$ITEM_DIR/index.html"
      if [[ ! -f "$INDEX_CACHE" ]]; then
        curl -sL -o "$INDEX_CACHE" "$INDEX_URL" 2>/dev/null || true
      fi
      if [[ -f "$INDEX_CACHE" ]]; then
        echo "Item '${ITEM_NAME}' not found. Available items:" >&2
        # Build the crate arg the extractor expects: crate for top-level, or crate/mod for submodules
        if [[ -n "$MODULE_PATH" ]]; then
          LIST_ARG="${CRATE_NAME_UNDERSCORED}/${MODULE_PATH%%/}"
        else
          LIST_ARG="${CRATE_NAME}"
        fi
        uv run --with beautifulsoup4 python3 "$EXTRACT_SCRIPT" list "$CACHE_ROOT" "$LIST_ARG" >&2 2>/dev/null || true
      fi
      die "Could not find '${TARGET}' on docs.rs."
    fi
  fi

  uv run --with beautifulsoup4 python3 "$EXTRACT_SCRIPT" "$MODE" "$CACHE_ROOT" "$TARGET"
  exit 0
fi

# --- Local mode: ensure Cargo.toml exists ---

[[ -f "Cargo.toml" ]] || die "No Cargo.toml in current directory. Run from a Rust project root, or use 'remote' mode."

# --- Ensure docs are generated and fresh ---

DOC_ROOT="target/doc"

needs_rebuild() {
  # Rebuild if docs don't exist or Cargo.lock is newer than the doc output
  if [[ ! -d "$DOC_ROOT" ]]; then
    return 0
  fi
  if [[ ! -f "Cargo.lock" ]]; then
    return 1  # No lock file, can't check staleness
  fi
  # Find any HTML file in doc root to compare against
  local any_html
  any_html=$(find "$DOC_ROOT" -name "index.html" -maxdepth 2 -print -quit 2>/dev/null)
  if [[ -z "$any_html" ]]; then
    return 0
  fi
  # Rebuild if Cargo.lock is newer than docs
  [[ "Cargo.lock" -nt "$any_html" ]]
}

if needs_rebuild; then
  echo "Generating docs (this may take a moment)..." >&2
  cargo doc --quiet 2>&1 | tail -5 >&2 \
    || die "cargo doc failed. Check compilation errors."
fi

# --- Run the Python extractor ---

uv run --with beautifulsoup4 python3 "$EXTRACT_SCRIPT" "$MODE" "$DOC_ROOT" "$TARGET"
