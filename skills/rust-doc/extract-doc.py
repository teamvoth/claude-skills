#!/usr/bin/env python3
"""Extract readable documentation from rustdoc HTML pages.

Usage:
    extract-doc.py list <doc-root> <crate>
    extract-doc.py lookup <doc-root> <crate>::<path>::<Item>

Requires beautifulsoup4 (use via `uv run --with beautifulsoup4`).
"""
import sys
import os
from pathlib import Path

from bs4 import BeautifulSoup, Tag


def die(msg: str) -> None:
    print(f"Error: {msg}", file=sys.stderr)
    sys.exit(1)


def read_soup(path: Path) -> BeautifulSoup:
    if not path.exists():
        die(f"Doc page not found: {path}")
    with open(path) as f:
        return BeautifulSoup(f, "html.parser")


def get_main_content(soup: BeautifulSoup) -> Tag:
    content = soup.find("section", id="main-content")
    if not content:
        # Fallback: try older rustdoc layout with div#main-content or div.main-heading
        content = soup.find("div", id="main-content")
    if not content:
        # Last resort: use the body tag
        content = soup.find("body")
    if not content:
        die("Could not find main-content section in HTML.")
    return content


# --- list mode ---


def list_crate(doc_root: Path, crate: str) -> None:
    # Handle both "crate" and "crate::module::submodule" and "crate/module" forms
    if "::" in crate:
        parts = crate.split("::")
        crate_dir = parts[0].replace("-", "_")
        index_path = doc_root / crate_dir / "/".join(parts[1:]) / "index.html"
    elif "/" in crate:
        crate_dir = crate.replace("-", "_")
        index_path = doc_root / crate_dir / "index.html"
    else:
        crate_dir = crate.replace("-", "_")
        index_path = doc_root / crate_dir / "index.html"
    soup = read_soup(index_path)
    content = get_main_content(soup)

    # Crate description from top-doc
    top_doc = content.find("details", class_="top-doc")
    if top_doc:
        desc = top_doc.get_text(separator=" ", strip=True)
        # Truncate to first paragraph
        first_para = desc.split("\n")[0][:300]
        print(f"# {crate}\n\n{first_para}\n")

    # Each section: Modules, Structs, Enums, Traits, Functions, Type Aliases, etc.
    for header in content.find_all("h2", class_="section-header"):
        section_name = header.get_text(strip=True).rstrip("§")
        # The items are in a <dl class="item-table"> sibling
        dl = header.find_next_sibling("dl", class_="item-table")
        if not dl:
            continue

        items = []
        # Each item is a <dt>/<dd> pair — dt has the name/link, dd has the summary
        for dt in dl.find_all("dt"):
            name_tag = dt.find("a")
            name = name_tag.get_text(strip=True) if name_tag else dt.get_text(strip=True)
            dd = dt.find_next_sibling("dd")
            summary = dd.get_text(separator=" ", strip=True)[:120] if dd else ""
            items.append((name, summary))

        if items:
            print(f"## {section_name}\n")
            for name, summary in items:
                if summary:
                    print(f"- **{name}** — {summary}")
                else:
                    print(f"- **{name}**")
            print()


# --- lookup mode ---


def format_code_block(pre_tag: Tag) -> str:
    """Extract text from a <pre> tag, preserving code structure."""
    return pre_tag.get_text()


def format_doc_text(details_tag: Tag) -> str:
    """Extract readable text from a top-doc or docblock details tag."""
    parts = []
    for child in details_tag.children:
        if not isinstance(child, Tag):
            continue
        if child.name == "p":
            parts.append(child.get_text(separator=" ", strip=True))
        elif child.name == "pre":
            parts.append(f"```\n{child.get_text()}\n```")
        elif child.name in ("ul", "ol"):
            for li in child.find_all("li", recursive=False):
                parts.append(f"  - {li.get_text(separator=' ', strip=True)}")
        elif child.name == "h3":
            parts.append(f"\n### {child.get_text(strip=True)}")
        elif child.name == "div" and "docblock" in child.get("class", []):
            # Recurse into docblock divs
            for sub in child.children:
                if isinstance(sub, Tag):
                    if sub.name == "p":
                        parts.append(sub.get_text(separator=" ", strip=True))
                    elif sub.name == "pre":
                        parts.append(f"```\n{sub.get_text()}\n```")
    return "\n\n".join(parts)


def lookup_item(doc_root: Path, path: str) -> None:
    # Parse path like "serde::Deserialize" or "anyhow::Error"
    parts = path.split("::")
    if len(parts) < 2:
        die(f"Path must be crate::Item or crate::module::Item, got: {path}")

    crate = parts[0].replace("-", "_")
    item_name = parts[-1]
    module_parts = parts[1:-1]

    # Build the directory path
    item_dir = doc_root / crate
    for mod_part in module_parts:
        item_dir = item_dir / mod_part

    # Try each item type prefix that rustdoc uses
    prefixes = ["struct", "trait", "enum", "fn", "macro", "type", "constant", "derive"]
    html_path = None
    item_type = None
    for prefix in prefixes:
        candidate = item_dir / f"{prefix}.{item_name}.html"
        if candidate.exists():
            html_path = candidate
            item_type = prefix
            break

    # Also try module index
    if not html_path:
        candidate = item_dir / item_name / "index.html"
        if candidate.exists():
            # It's a module — redirect to list mode
            print(f"# {path} (module)\n")
            list_crate(doc_root, "/".join([crate] + module_parts + [item_name]))
            return

    if not html_path:
        # Search the crate root for re-exported items before giving up
        crate_root = doc_root / crate
        if crate_root.exists() and item_dir != crate_root:
            for prefix in prefixes:
                candidate = crate_root / f"{prefix}.{item_name}.html"
                if candidate.exists():
                    html_path = candidate
                    item_type = prefix
                    break

    if not html_path:
        # List available items in the directory to help
        available = []
        if item_dir.exists():
            for f in sorted(item_dir.iterdir()):
                if f.suffix == ".html" and "." in f.stem:
                    fparts = f.stem.split(".", 1)
                    available.append(f"{fparts[0]} {fparts[1]}")
        if available:
            die(
                f"Item '{item_name}' not found in {item_dir}.\n"
                f"Available items:\n" + "\n".join(f"  {a}" for a in available)
            )
        else:
            die(f"Item '{item_name}' not found and directory {item_dir} has no doc pages.")

    soup = read_soup(html_path)
    content = get_main_content(soup)

    # Header
    print(f"# {path} ({item_type})\n")

    # Signature from item-decl
    decl = content.find("pre", class_="item-decl")
    if decl:
        print(f"```rust\n{decl.get_text().strip()}\n```\n")

    # Doc comment from top-doc
    top_doc = content.find("details", class_="top-doc")
    if top_doc:
        print(format_doc_text(top_doc))
        print()

    # Implementations — method signatures
    impl_list = content.find("div", id="implementations-list")
    if impl_list:
        methods = []
        for section in impl_list.find_all("section", recursive=False):
            # Each method has an h4 with the signature and optionally a docblock
            heading = section.find(["h3", "h4"])
            if not heading:
                continue
            sig = heading.get_text(separator=" ", strip=True).rstrip("§")
            # Get short doc if present
            docblock = section.find("div", class_="docblock")
            short_doc = ""
            if docblock:
                first_p = docblock.find("p")
                if first_p:
                    short_doc = first_p.get_text(separator=" ", strip=True)[:150]
            methods.append((sig, short_doc))

        if methods:
            print("## Methods\n")
            for sig, doc in methods:
                print(f"- `{sig}`")
                if doc:
                    print(f"  {doc}")
            print()


# --- main ---


def main() -> None:
    if len(sys.argv) < 3:
        print(__doc__, file=sys.stderr)
        sys.exit(1)

    mode = sys.argv[1]
    doc_root = Path(sys.argv[2])

    if not doc_root.exists():
        die(f"Doc root not found: {doc_root}")

    if mode == "list":
        if len(sys.argv) != 4:
            die("Usage: extract-doc.py list <doc-root> <crate>")
        list_crate(doc_root, sys.argv[3])

    elif mode == "lookup":
        if len(sys.argv) != 4:
            die("Usage: extract-doc.py lookup <doc-root> <crate::path::Item>")
        lookup_item(doc_root, sys.argv[3])

    else:
        die(f"Unknown mode: {mode}. Use 'list' or 'lookup'.")


if __name__ == "__main__":
    main()
