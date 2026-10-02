#!/usr/bin/env python3
"""Checks the translations against the last build: every text the code shows has Spanish, and nothing in
the catalog is left over. The build writes what it finds in the code (`*.stringsdata`); this reads them.

    python3 swift/tools/traducciones.py        # after building (probar.sh hoja/abrir builds)

Prints the keys missing from SAVERS/Resources/Localizable.xcstrings or without Spanish, and the ones no
longer used. Exits with 1 if something is missing.
"""
import json, pathlib, sys

HERE = pathlib.Path(__file__).resolve().parent.parent
CATALOG = HERE / "SAVERS/Resources/Localizable.xcstrings"
BUILD = HERE.parent / "swift-build/Build/Intermediates.noindex/SAVERS.build/Debug-iphonesimulator/SAVERS.build"

used = {}
for f in BUILD.rglob("*.stringsdata"):
    data = json.loads(f.read_text())
    for row in data.get("tables", {}).get("Localizable", []):
        used.setdefault(row["key"], f"{pathlib.Path(data['source']).name}:{row['location']['startingLine']}")

strings = json.loads(CATALOG.read_text())["strings"]
def spanish(entry):
    es = entry.get("localizations", {}).get("es", {})
    return "stringUnit" in es or "variations" in es

missing = sorted(k for k in used if k not in strings or not spanish(strings[k]))
unused = sorted(k for k in strings if k not in used)
for k in missing: print(f"falta  {used[k]:32} {k!r}")
for k in unused: print(f"sobra  {k!r}")
print(f"{len(used)} textos en el código, {len(missing)} sin español, {len(unused)} sin usar")
sys.exit(1 if missing else 0)
