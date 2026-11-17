"""Verify the release place matches the script sync and excludes the Studio harness."""

import hashlib
import json
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

SCRIPT_CLASSES = {"Script", "LocalScript", "ModuleScript", "CoreScript"}


def place_items(element, parent=()):
    for item in element.findall("Item"):
        name = item.findtext("Properties/string[@name='Name']")
        path = (*parent, name or item.attrib["class"])
        yield path, item
        yield from place_items(item, path)


def sync_scripts(entry, parent=()):
    for child in entry.get("children", []):
        path = (*parent, child["name"])
        if child["className"] in SCRIPT_CLASSES:
            sources = child.get("filePaths", [])
            assert sources and all(Path(source).parts[0] == "src" for source in sources), path
            yield path, child["className"]
        yield from sync_scripts(child, path)


def verify(first, second, sync):
    release = first.read_bytes()
    assert release == second.read_bytes(), "The two Rojo builds differ"
    items = list(place_items(ET.fromstring(release)))
    scripts = [(path, item.attrib["class"]) for path, item in items if item.attrib["class"] in SCRIPT_CLASSES]
    manifest = json.loads(sync.read_text(encoding="utf-8"))
    expected = list(sync_scripts(manifest))
    assert expected and sorted(scripts) == sorted(expected), (
        "Release scripts differ from the source-only sync",
        sorted(set(scripts) - set(expected)),
        sorted(set(expected) - set(scripts)),
    )
    assert "Workspace" not in {child["name"] for child in manifest["children"]}, "Script sync manages the map"
    assert all(not any(name.startswith("UmbralQA") for name in path) for path, _ in items), "QA instance in release"
    arena = ("Workspace", "UmbralWorld", "EstacionDeRelevo")
    bounds = [item for path, item in items if path == (*arena, "PlayableBounds")]
    assert len(bounds) == 1 and bounds[0].attrib["class"] == "Part", "Missing or duplicated PlayableBounds"
    for name, value in (("Anchored", True), ("CanQuery", False), ("CanCollide", False), ("CanTouch", False)):
        prop = bounds[0].findtext(f"Properties/bool[@name='{name}']")
        assert prop in {"true", "false"} and (prop == "true") == value, f"Invalid PlayableBounds {name}"
    spawn_folder = (*arena, "Spawns")
    spawns = [item for path, item in items if path[:-1] == spawn_folder]
    assert len(spawns) >= 8, "The arena cannot provide a spawn for every supported seat"
    print(f"Verified {len(scripts)} scripts, {len(spawns)} spawn markers and no QA instances")
    print("SHA-256 " + hashlib.sha256(release).hexdigest())


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("Usage: python tests/verify_place.py place.rbxlx rebuild.rbxlx sync.json")
    verify(*(Path(path) for path in sys.argv[1:]))
