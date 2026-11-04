#!/usr/bin/env python3
"""Fail if anything chosen (catalog items, core packages, runtimes' packages,
nvim plugins) has no entry in docs/stack.yaml."""
import pathlib, re, sys

root = pathlib.Path(__file__).resolve().parent.parent
stack = (root / "docs/stack.yaml").read_text()
names = set(re.findall(r"name:\s*([A-Za-z0-9._-]+)", stack))

want = set()
for f in (root / "home/.chezmoidata/catalog").glob("*.yaml"):
    if f.name.startswith("_"):
        continue
    want |= set(re.findall(r"^  ([a-z0-9-]+):", f.read_text(), re.M))
pk = (root / "home/.chezmoidata/packages.yaml").read_text()
core = pk.split("core:")[1].split("\n\n")[0]
want |= set(re.findall(r"^\s+- ([a-z0-9-]+)", core, re.M))
rt = (root / "home/.chezmoidata/runtimes.yaml").read_text()
for m in re.findall(r"packages: \[([^\]]*)\]", rt):
    want |= {x.strip() for x in m.split(",") if x.strip() and x.strip() != "go"}
pack = (root / "home/dot_config/nvim/lua/config/pack.lua").read_text()
want |= set(re.findall(r"github\.com/[^/\"]+/([^\"/]+)\"", pack))

missing = sorted(want - names)
if missing:
    sys.exit("docs/stack.yaml has no entry for: " + ", ".join(missing))
print(f"stack: all {len(want)} chosen components have an entry")
