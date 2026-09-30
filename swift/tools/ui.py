"""AXe's describe-ui JSON as one short line per element that says something: type, label, value, frame in points.

    axe describe-ui --udid … | python3 ui.py
"""
import json
import sys


def walk(node, depth=0):
    label = node.get("AXLabel") or node.get("title")
    value = node.get("AXValue")
    kind = node.get("type") or node.get("role", "")
    if label or value or kind in ("Button", "TextField", "TextArea", "Switch", "Slider"):
        f = node.get("frame") or {}
        box = f"{f.get('x', 0):.0f},{f.get('y', 0):.0f} {f.get('width', 0):.0f}x{f.get('height', 0):.0f}"
        parts = [kind, repr(label) if label else "", f"= {value!r}" if value else "", f"@{box}"]
        print("  " * min(depth, 6) + " ".join(p for p in parts if p))
    for child in node.get("children") or []:
        walk(child, depth + 1)


for root in json.load(sys.stdin):
    walk(root)
