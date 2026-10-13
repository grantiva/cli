#!/usr/bin/env python3
import json
import pathlib
import re
import statistics
import sys

mode_root = pathlib.Path(sys.argv[1])
bounds_re = re.compile(r"\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]")

def positions(path):
    result = {}
    for node in json.loads(path.read_text()):
        text = node.get("text", "")
        match = bounds_re.fullmatch(node.get("bounds", ""))
        if text and match and (text.startswith("Landmark ") or text in {
            "Golden Gate Bridge", "Lake Tahoe", "Half Dome", "Yosemite Valley",
            "Bixby Creek Bridge", "Mono Lake", "Mount Shasta", "Crater Lake",
            "Brooklyn Bridge", 'Mount "Denali"',
        }):
            result[text] = (int(match.group(1)), int(match.group(2)),
                            int(match.group(3)), int(match.group(4)))
    return result

rows = []
for form in ("direction", "coordinates", "element", "engine-adb"):
    run = mode_root / f"l51-{form}-final"
    before = positions(run / "app-only-before.json")
    after = positions(run / "app-only-after.json")
    common = sorted(before.keys() & after.keys())
    deltas = {name: after[name][1] - before[name][1] for name in common}
    rows.append({
        "form": form,
        "beforeRows": before,
        "afterRows": after,
        "commonRows": common,
        "yDeltas": deltas,
        "medianYDelta": statistics.median(deltas.values()) if deltas else None,
        "moved": before != after,
    })
print(json.dumps(rows, indent=2))
