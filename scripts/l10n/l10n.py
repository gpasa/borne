#!/usr/bin/env python3
"""Traductions de Borne : du code au catalogue Resources/Localizable.xcstrings.

    scripts/l10n/l10n.py extract   textes du code (xcodebuild -exportLocalizations)
                                   → scripts/l10n/strings.txt, un par ligne
    scripts/l10n/l10n.py missing   textes sans traduction anglaise
    scripts/l10n/l10n.py build     écrit le catalogue depuis scripts/l10n/en.json

Le français est la langue source : les clés sont les textes français du code.
en.json associe chaque texte français à sa traduction anglaise, à la main ;
les spécificateurs (%@, %lld, %1$@…) doivent s'y retrouver à l'identique.
"""
import json
import os
import re
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HERE = os.path.join(ROOT, "scripts", "l10n")
CATALOG = os.path.join(ROOT, "Resources", "Localizable.xcstrings")
STRINGS = os.path.join(HERE, "strings.txt")
EN = os.path.join(HERE, "en.json")
# Clés distinctes d'un même mot français (« Borne », l'app, et « Borne », l'image du
# meuble) : leur texte français est donné ici.
FR = {"Borne d’arcade": "Borne"}
SPEC = re.compile(r"%(?:\d+\$)?(?:lld|ld|d|@|f|\.\d+f|%)")


def extract():
    out = tempfile.mkdtemp(prefix="borne-l10n-")
    subprocess.run(["xcodegen", "generate", "-q"], cwd=ROOT, check=True)
    subprocess.run(["xcodebuild", "-exportLocalizations", "-project", "Borne.xcodeproj",
                    "-localizationPath", out, "-exportLanguage", "en", "-quiet"], cwd=ROOT, check=True)
    xliff = os.path.join(out, "en.xcloc", "Localized Contents", "en.xliff")
    ns = {"x": "urn:oasis:names:tc:xliff:document:1.2"}
    keys = []
    for f in ET.parse(xliff).getroot().findall("x:file", ns):
        if "InfoPlist" in f.get("original", ""):
            continue
        for tu in f.iter("{urn:oasis:names:tc:xliff:document:1.2}trans-unit"):
            k = tu.get("id")
            if k and k not in keys:
                keys.append(k)
    with open(STRINGS, "w") as fh:
        fh.write("\n".join(k.replace("\n", "\\n") for k in keys) + "\n")
    print(f"{len(keys)} textes → {STRINGS}")


def load_keys():
    with open(STRINGS) as fh:
        return [l.rstrip("\n").replace("\\n", "\n") for l in fh if l.strip()]


def load_en():
    if not os.path.exists(EN):
        return {}
    with open(EN) as fh:
        return json.load(fh)


def missing():
    en = load_en()
    todo = [k for k in load_keys() if k not in en]
    for k in todo:
        print(json.dumps(k, ensure_ascii=False))
    print(f"{len(todo)} sans traduction", file=sys.stderr)


def build():
    en = load_en()
    keys = load_keys()
    errors = []
    strings = {}
    for k in keys:
        entry = {}
        if k in en:
            v = en[k]
            if sorted(SPEC.findall(k)) != sorted(SPEC.findall(v)):
                errors.append(f"spécificateurs différents : {k!r} → {v!r}")
            entry["localizations"] = {"en": {"stringUnit": {"state": "translated", "value": v}}}
        if k in FR:
            entry.setdefault("localizations", {})["fr"] = {"stringUnit": {"state": "translated", "value": FR[k]}}
        strings[k] = entry
    unused = [k for k in en if k not in strings]
    catalog = {"sourceLanguage": "fr", "strings": dict(sorted(strings.items())), "version": "1.0"}
    with open(CATALOG, "w") as fh:
        json.dump(catalog, fh, ensure_ascii=False, indent=2, separators=(",", " : "))
        fh.write("\n")
    done = sum(1 for k in keys if k in en)
    print(f"{done}/{len(keys)} traduits ; {len(unused)} traductions inutilisées")
    for e in errors:
        print(e)
    if errors:
        sys.exit(1)


if __name__ == "__main__":
    {"extract": extract, "missing": missing, "build": build}[sys.argv[1]]()
