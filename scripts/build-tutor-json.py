#!/usr/bin/env python3
"""Write dotfiles.tutor.json: which exercise lines must become what.

Neovim's tutor checks exercises by line number, so the numbers are worked out
here from the text: edit the course freely, then run this script.
"""
import json, pathlib, sys

TUTOR = pathlib.Path(__file__).resolve().parent.parent / "home/dot_config/nvim/tutor/dotfiles.tutor"

# exercise line as written -> what it should look like when done
EXERCISES = {
    "print(name)": 'print("name")',
    "print('done')": 'print("done")',
    "[remove these brackets]": "remove these brackets",
    "call(first, second)": "call(first)",
    "call(old, args)": "call(new)",
}

lines = TUTOR.read_text().splitlines()
expect = {}
for start, goal in EXERCISES.items():
    hits = [i + 1 for i, l in enumerate(lines) if l == start]
    if len(hits) != 1:
        sys.exit(f"exercise line {start!r} found {len(hits)} times (needs exactly once)")
    expect[str(hits[0])] = goal
out = TUTOR.with_name(TUTOR.name + ".json")
text = json.dumps({"expect": expect}, indent=2) + "\n"
if "--check" in sys.argv:
    if not out.exists() or out.read_text() != text:
        sys.exit("dotfiles.tutor.json is out of date: run scripts/build-tutor-json.py")
    print(f"tutor: {len(expect)} exercises, line numbers up to date")
else:
    out.write_text(text)
    print(f"wrote {out.relative_to(TUTOR.parents[4])}: {len(expect)} exercises")
