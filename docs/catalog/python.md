# python

Python support: **pyright** (types, go-to-definition) and **ruff** (lint, format, import sorting) in Neovim, plus **uv** for environments and running tools.

- Format on save: ruff organise imports, then ruff format.
- `uv run <cmd>` runs inside the project's environment; `uv add <pkg>` adds a dependency.
- Add or remove: `rig add python` / `rig remove python` (or tick it in `rig setup`).
