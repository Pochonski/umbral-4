"""Produce a separate Studio integration place with shorter round timers."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
if len(sys.argv) != 3:
    raise SystemExit("Usage: python tests/build_studio_qa.py path_to_rojo output.rbxlx")
rojo, output = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()
project = json.loads((root / "default.project.json").read_text(encoding="utf-8"))
services = project["tree"]
for group, filename in (
    (services["ServerScriptService"], "StudioServer.server.luau"),
    (services["StarterPlayer"]["StarterPlayerScripts"], "StudioClient.client.luau"),
):
    group["UmbralQA"] = {"$path": "tests/" + filename}

with tempfile.TemporaryDirectory(prefix="umbral-qa-", dir=root) as directory:
    temporary = Path(directory)
    config = (root / "src/shared/Config.luau").read_text(encoding="utf-8")
    for old, new in (
        ("Countdown = 10", "Countdown = 1"),
        ("RoundDuration = 240", "RoundDuration = 35"),
        ("ResultsDuration = 10", "ResultsDuration = 1.2"),
        ("RespawnDelay = 6", "RespawnDelay = 1.4"),
    ):
        config = config.replace(old, new, 1)
    manifest = temporary / "default.project.json"
    for location in (
        services["Workspace"]["UmbralWorld"],
        services["ServerScriptService"]["UmbralServer"],
        services["ServerScriptService"]["UmbralQA"],
        services["StarterPlayer"]["StarterPlayerScripts"]["UmbralClient"],
        services["StarterPlayer"]["StarterPlayerScripts"]["UmbralQA"],
    ):
        location["$path"] = "../" + location["$path"]
    services["ReplicatedStorage"]["UmbralShared"]["$path"] = "shared"
    shutil.copytree(root / "src/shared", temporary / "shared")
    (temporary / "shared/Config.luau").write_text(config, encoding="utf-8")
    manifest.write_text(json.dumps(project), encoding="utf-8")
    subprocess.run([str(rojo), "build", str(manifest), "-o", str(output)], check=True)
