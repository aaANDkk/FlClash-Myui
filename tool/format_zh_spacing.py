#!/usr/bin/env python3
"""Normalize CJK-Latin/digit spacing in Simplified Chinese localization copy.

Inserts a single ASCII space between CJK ideographs and adjacent ASCII letters
or digits (e.g. "DNS查询" -> "DNS 查询", "基于ClashMeta的" -> "基于 ClashMeta 的")
in `arb/intl_zh.arb` and keeps the corresponding string literals in
`lib/l10n/l10n_zh.dart` synchronized.

Designed to be re-run safely and idempotently after every upstream merge:
    python tool/format_zh_spacing.py          # format in place
    python tool/format_zh_spacing.py --check  # verify without modifying files
    python tool/format_zh_spacing.py --diff   # preview changes only
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys
from typing import List, Tuple

CJK = r"\u4e00-\u9fff"
CJK_TO_ALNUM = re.compile(rf"([{CJK}])([A-Za-z0-9])")
ALNUM_TO_CJK = re.compile(rf"([A-Za-z0-9])([{CJK}])")


def _format_plain_text(text: str) -> str:
    """Apply CJK <-> ASCII alphanumeric spacing to a plain text segment."""
    text = CJK_TO_ALNUM.sub(r"\1 \2", text)
    text = ALNUM_TO_CJK.sub(r"\1 \2", text)
    return text


def _find_matching_brace(text: str, start: int) -> int:
    """Return index of '}' matching '{' at `start`, or -1 if unbalanced."""
    depth = 0
    i = start
    n = len(text)
    while i < n:
        ch = text[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def format_icu_message(text: str) -> str:
    """Format a localized ICU MessageFormat string without corrupting placeholders.

    - Plain text segments get standard CJK <-> ASCII alphanumeric spacing.
    - Simple placeholders like `{label}` are preserved untouched.
    - Nested ICU blocks like `{count, plural, other{...}}` preserve their syntax
      and recursively format only the localized text inside each branch.
    """
    out: List[str] = []
    i = 0
    n = len(text)
    plain_start = 0

    while i < n:
        if text[i] != "{":
            i += 1
            continue

        end = _find_matching_brace(text, i)
        if end == -1:
            i += 1
            continue

        if i > plain_start:
            out.append(_format_plain_text(text[plain_start:i]))

        inner = text[i + 1 : end]
        # Check if this is an ICU plural/select/selectordinal block.
        icu_match = re.match(
            r"^(\s*[A-Za-z0-9_]+\s*,\s*(?:plural|select|selectordinal)\s*,)(.*)$",
            inner,
            flags=re.DOTALL,
        )
        if icu_match:
            header, rest = icu_match.group(1), icu_match.group(2)
            out.append("{" + header + _format_icu_branches(rest) + "}")
        else:
            # Simple placeholder or format spec (e.g. {label}, {n, number}): keep verbatim.
            out.append(text[i : end + 1])

        i = end + 1
        plain_start = i

    if plain_start < n:
        out.append(_format_plain_text(text[plain_start:]))

    return "".join(out)


def _format_icu_branches(branches: str) -> str:
    """Recursively format message bodies inside ICU plural/select branches."""
    out: List[str] = []
    i = 0
    n = len(branches)
    while i < n:
        if branches[i] != "{":
            out.append(branches[i])
            i += 1
            continue
        end = _find_matching_brace(branches, i)
        if end == -1:
            out.append(branches[i:])
            break
        body = branches[i + 1 : end]
        out.append("{" + format_icu_message(body) + "}")
        i = end + 1
    return "".join(out)


def _dart_escape_single_quoted(value: str) -> str:
    """Match flutter gen-l10n single-quoted Dart literal escaping."""
    escaped = (
        value.replace("\\", "\\\\")
        .replace("'", "\\'")
        .replace("$", "\\$")
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t")
    )
    return escaped


def _sync_l10n_dart(
    dart_path: pathlib.Path,
    arb_data: dict,
    *,
    write: bool,
) -> Tuple[int, List[str]]:
    """Sync CJK spacing in `lib/l10n/l10n_zh.dart` to match `arb/intl_zh.arb`."""
    if not dart_path.exists():
        return 0, []

    original = dart_path.read_bytes().decode("utf-8")
    updated = original
    synced = 0
    missed: List[str] = []

    for key, new_val in arb_data.items():
        if key.startswith("@") or not isinstance(new_val, str):
            continue
        member_re = re.compile(
            rf"(String\s+(?:get\s+{re.escape(key)}\b|{re.escape(key)}\s*\([^)]*\))[\s\S]*?;)"
        )
        match = member_re.search(updated)
        if not match:
            continue

        block = match.group(1)

        def _format_dart_literal(m: re.Match) -> str:
            literal = m.group(1)
            # Only format plain localized string parts, preserving $var / ${var} and escapes.
            parts = re.split(r"(\\[nrt'\"\\$]|\$\{[^}]+\}|\$[A-Za-z_][A-Za-z0-9_]*)", literal)
            rebuilt = []
            for idx, part in enumerate(parts):
                if idx % 2 == 1:
                    rebuilt.append(part)
                else:
                    rebuilt.append(_format_plain_text(part))
            return "'" + "".join(rebuilt) + "'"

        new_block = re.sub(r"'((?:\\.|[^'\\])*)'", _format_dart_literal, block)
        if new_block != block:
            updated = updated[: match.start(1)] + new_block + updated[match.end(1) :]
            synced += 1

    if write and updated != original:
        dart_path.write_bytes(updated.encode("utf-8"))

    return synced, missed


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Normalize CJK-Latin/digit spacing in Simplified Chinese ARB copy."
    )
    parser.add_argument(
        "--arb",
        type=pathlib.Path,
        default=pathlib.Path("arb/intl_zh.arb"),
        help="Path to the Simplified Chinese ARB file (default: arb/intl_zh.arb).",
    )
    parser.add_argument(
        "--dart",
        type=pathlib.Path,
        default=pathlib.Path("lib/l10n/l10n_zh.dart"),
        help="Path to generated Dart l10n file to keep in sync (default: lib/l10n/l10n_zh.dart).",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Check only; exit with code 1 if any Simplified Chinese entry needs spacing.",
    )
    parser.add_argument(
        "--diff",
        action="store_true",
        help="Print proposed changes without writing files.",
    )
    args = parser.parse_args()

    repo_root = pathlib.Path(__file__).resolve().parent.parent
    arb_path = args.arb if args.arb.is_absolute() else repo_root / args.arb
    dart_path = args.dart if args.dart.is_absolute() else repo_root / args.dart

    raw_bytes = arb_path.read_bytes()
    raw_text = raw_bytes.decode("utf-8")
    eol = "\r\n" if "\r\n" in raw_text else "\n"
    trailing_newline = raw_text.endswith("\n")

    data = json.loads(raw_text)
    changes: List[Tuple[str, str, str]] = []

    for key, value in list(data.items()):
        if key.startswith("@") or not isinstance(value, str):
            continue
        formatted = format_icu_message(value)
        if formatted != value:
            changes.append((key, value, formatted))
            data[key] = formatted

    if not changes:
        synced, _ = _sync_l10n_dart(dart_path, data, write=not (args.check or args.diff))
        if synced > 0:
            if args.check or args.diff:
                print(
                    f"Found {synced} entries in {dart_path.relative_to(repo_root)} "
                    "needing spacing sync."
                )
                return 1 if args.check else 0
            print(
                f"Synced {synced} entries in {dart_path.relative_to(repo_root)} "
                f"(ARB already clean)."
            )
            return 0
        print(f"OK: {arb_path.relative_to(repo_root)} already follows CJK spacing rules.")
        return 0

    for key, old_val, new_val in changes:
        print(f"- {key}:")
        print(f"    - {old_val}")
        print(f"    + {new_val}")

    if args.check or args.diff:
        print(f"\nFound {len(changes)} Simplified Chinese entries needing spacing.")
        return 1 if args.check else 0

    serialized = json.dumps(data, ensure_ascii=False, indent=2)
    if eol != "\n":
        serialized = serialized.replace("\n", eol)
    if trailing_newline:
        serialized += eol
    arb_path.write_bytes(serialized.encode("utf-8"))

    synced, missed = _sync_l10n_dart(dart_path, data, write=True)
    print(
        f"\nUpdated {len(changes)} entries in {arb_path.relative_to(repo_root)} "
        f"(synced {synced} entries in {dart_path.relative_to(repo_root)})."
    )
    if missed:
        print(
            "Note: the following keys in l10n_zh.dart were not auto-matched "
            "(run `flutter gen-l10n` to regenerate): " + ", ".join(missed)
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
