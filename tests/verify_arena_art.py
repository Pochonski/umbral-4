"""Check that the arena artwork preserves the reference model's gameplay geometry."""

from collections import Counter
from pathlib import Path
import subprocess
import sys
import xml.etree.ElementTree as ET

from verify_place import place_items


MODEL_PATH = "map/EstacionDeRelevo.rbxmx"
ROOT = Path(__file__).resolve().parents[1]
FLAGS = ("CanCollide", "CanTouch", "CanQuery")
PART_CLASSES = {"Part", "WedgePart", "SpawnLocation"}
ARENA_PATH = ("UmbralWorld", "EstacionDeRelevo")
RELIEF_GROUPS = {"Celda 04 · transferencia", "Fachadas · sectores operativos", "Pasarelas · estructura y galerías"}
SHAPE = ("CFrame", "size", "shape", "CollisionGroup", "CollisionGroupId",
         "CustomPhysicalProperties", "Anchored", *FLAGS)


def property_values(node):
    return node.tag, (node.text or "").strip(), tuple(property_values(child) for child in node)


def geometry(xml):
    physical = Counter()
    markers = Counter()
    scenery = 0
    relief = 0
    for path, item in place_items(ET.fromstring(xml)):
        kind = item.attrib["class"]
        assert kind in PART_CLASSES | {"Model", "Folder", "SurfaceGui", "TextLabel", "SurfaceLight"}, (
            f"Review the new instance class {kind} at {'/'.join(path)}"
        )
        if kind not in PART_CLASSES:
            continue
        props = {node.attrib["name"]: node for node in item.find("Properties")}
        assert all(name in props and props[name].text in {"true", "false"} for name in FLAGS), path
        signature = (path, kind, tuple(property_values(props[name]) if name in props else None for name in SHAPE))
        if path[:2] == ARENA_PATH and len(path) > 3 and path[2] in RELIEF_GROUPS:
            assert props["Anchored"].text == "true", path
            assert props["CanCollide"].text == props["CanTouch"].text == "false", path
            if props["CanQuery"].text == "true":
                assert "Transparency" not in props or float(props["Transparency"].text) < .35, path
                relief += 1
                continue
        if path[-1] in {"PlayableBounds", "Arrival"} or path[-2] == "Spawns":
            markers[signature] += 1
        if any(props[name].text == "true" for name in FLAGS):
            physical[signature] += 1
        else:
            assert props["Anchored"].text == "true", path
            scenery += 1
    return physical, markers, scenery, relief


def verify(reference):
    baseline = subprocess.check_output(["git", "show", f"{reference}:{MODEL_PATH}"], cwd=ROOT)
    before, markers_before, art_before, relief_before = geometry(baseline)
    after, markers_after, art_after, relief_after = geometry((ROOT / MODEL_PATH).read_bytes())
    for label, old, new in (("physics/query/touch volumes", before, after), ("arena markers", markers_before, markers_after)):
        assert old and old == new, (
            label, sorted("/".join(key[0]) for key in old - new), sorted("/".join(key[0]) for key in new - old),
        )
        print(f"Verified {sum(old.values())} identical {label}")
    print(f"Non-interactive anchored parts: {art_before} -> {art_after}")
    print(f"Visible non-colliding relief included in raycasts: {relief_before} -> {relief_after}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python tests/verify_arena_art.py <baseline-git-ref>")
    verify(sys.argv[1])
