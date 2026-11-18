"""Produce a separate Studio integration place with shorter round timers."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
if len(sys.argv) not in (3, 4) or (len(sys.argv) == 4 and sys.argv[3] not in ("--menu", "--maps", "--transitions", "--transitions-single")):
    raise SystemExit("Usage: python tests/build_studio_qa.py path_to_rojo output.rbxlx [--menu|--maps|--transitions|--transitions-single]")
mode = sys.argv[3] if len(sys.argv) == 4 else ""
transitions = mode.startswith("--transitions")
rojo, output = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()
project = json.loads((root / "default.project.json").read_text(encoding="utf-8"))
services = project["tree"]
if mode == "--menu":
    services["Workspace"].setdefault("$attributes", {})["UmbralMenuQA"] = True
if transitions:
    services["Workspace"].setdefault("$attributes", {})["UmbralTransitionClients"] = 1 if mode.endswith("-single") else 2
for group, filename in (
    (services["ServerScriptService"], "StudioServer.server.luau"),
    (services["StarterPlayer"]["StarterPlayerScripts"], "StudioClient.client.luau"),
):
    if transitions: filename = filename.replace("Studio", "Transition")
    group["UmbralQA"] = {"$path": "tests/" + ("maps/" if mode == "--maps" or transitions else "") + filename}

with tempfile.TemporaryDirectory(prefix="umbral-qa-", dir=root) as directory:
    temporary = Path(directory)
    config = (root / "src/shared/Config.luau").read_text(encoding="utf-8")
    for old, new in (
        ("Countdown = 10", "Countdown = 3"),
        ("RoundDuration = 240", "RoundDuration = 35"),
        ("ResultsDuration = 10", "ResultsDuration = 1.2"),
        ("RespawnDelay = 6", "RespawnDelay = 1.4"),
    ):
        config = config.replace(old, new, 1)
    if len(sys.argv) == 4 and sys.argv[3] == "--maps":
        config = config.replace("VoteDuration = 10", "VoteDuration = 6").replace("RoundDuration = 35", "RoundDuration = 20")
    if transitions:
        config = config.replace("VoteDuration = 10", "VoteDuration = 8").replace("RoundDuration = 35", "RoundDuration = 26")
        if mode.endswith("-single"): config = config.replace("MinPlayers = 2", "MinPlayers = 1")
    manifest = temporary / "default.project.json"
    for location in (
        services["Workspace"]["UmbralWorld"],
        services["ServerScriptService"]["UmbralServer"],
        services["ServerScriptService"]["UmbralQA"],
        services["StarterPlayer"]["StarterPlayerScripts"]["UmbralClient"],
        services["StarterPlayer"]["StarterPlayerScripts"]["UmbralQA"],
    ):
        location["$path"] = "../" + location["$path"]
    for entry in services.get("ServerStorage", {}).get("UmbralMapTemplates", {}).values():
        if isinstance(entry, dict) and "$path" in entry: entry["$path"] = "../" + entry["$path"]
    services["ReplicatedStorage"]["UmbralMapPreviews"]["$path"] = "../" + services["ReplicatedStorage"]["UmbralMapPreviews"]["$path"]
    services["ReplicatedStorage"]["UmbralShared"]["$path"] = "shared"
    shutil.copytree(root / "src/shared", temporary / "shared")
    (temporary / "shared/Config.luau").write_text(config, encoding="utf-8")
    manifest.write_text(json.dumps(project), encoding="utf-8")
    subprocess.run([str(rojo), "build", str(manifest), "-o", str(output)], check=True)
