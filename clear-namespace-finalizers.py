import json

ns = "cert-manager"

with open("/tmp/ns.json", "r", encoding="utf-8") as handle:
    data = json.load(handle)

metadata = data.setdefault("metadata", {})
metadata["finalizers"] = []

spec = data.setdefault("spec", {})
spec["finalizers"] = []

with open("/tmp/ns-fixed.json", "w", encoding="utf-8") as handle:
    json.dump(data, handle)
