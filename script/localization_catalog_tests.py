#!/usr/bin/env python3
"""Check that every L()/LF() key exists in all four languages and placeholders match."""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "QuickDoc" / "Resources" / "QuickDocLocalizable.json"
LANGUAGES = ("zh-Hans", "en", "zh-Hant", "ja")
PLACEHOLDER = re.compile(r"%(?:\d+\$)?[@dDuUxXoOfeEgGcCsSpaAF]")
CALL = re.compile(r'\bL(?:F)?\(\s*"((?:\\.|[^"\\])*)"')


def unescape(value: str) -> str:
    return (
        value.replace(r"\"", '"')
        .replace(r"\n", "\n")
        .replace(r"\\", "\\")
    )


def placeholders(value: str) -> list[str]:
    return PLACEHOLDER.findall(value)


def main() -> int:
    failures = []
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    for language in LANGUAGES:
        if language not in catalog:
            failures.append(f"missing table {language}")
    tables = {language: catalog.get(language, {}) for language in LANGUAGES}
    if tables["zh-Hans"].keys() != tables["en"].keys() or tables["zh-Hans"].keys() != tables["zh-Hant"].keys() or tables["zh-Hans"].keys() != tables["ja"].keys():
        failures.append("language tables do not contain the same keys")

    for key, value in tables["zh-Hans"].items():
        if value != key:
            failures.append(f"zh-Hans changed: {key}")
        expected = placeholders(key)
        for language in LANGUAGES:
            translated = tables[language].get(key, "")
            if not translated:
                failures.append(f"empty {language}: {key}")
            if placeholders(translated) != expected:
                failures.append(f"placeholder mismatch {language}: {key} -> {translated}")

    used = set()
    for path in list((ROOT / "QuickDoc").rglob("*.swift")) + list((ROOT / "QuickDocFinderSync").rglob("*.swift")):
        for match in CALL.finditer(path.read_text(encoding="utf-8")):
            used.add(unescape(match.group(1)))
    missing = sorted(key for key in used if key not in tables["zh-Hans"])
    for key in missing:
        failures.append(f"missing catalog key: {key}")

    info_dirs = [
        ROOT / "QuickDoc",
        ROOT / "QuickDocFinderSync",
        ROOT / "QuickDocLoginItem",
    ]
    info_key = re.compile(r'^"([^"]+)"\s*=')
    for directory in info_dirs:
        found = {}
        for language in LANGUAGES:
            text = (directory / f"{language}.lproj" / "InfoPlist.strings").read_text(encoding="utf-8")
            found[language] = {match.group(1) for match in info_key.finditer(text)}
            if not found[language]:
                failures.append(f"empty InfoPlist {directory.name} {language}")
        base = found["en"]
        for language in LANGUAGES:
            if found[language] != base:
                failures.append(f"InfoPlist keys differ {directory.name} {language}")

    if failures:
        print("\n".join(failures))
        print(f"FAIL {len(failures)}")
        return 1
    print(f"PASS localization keys={len(tables['zh-Hans'])} used={len(used)} languages={','.join(LANGUAGES)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
