# lang-python

Python support: **pyright** (types, go-to-definition) and **ruff** (lint, format, import sorting) in Neovim, plus **uv** for environments and running tools.

- Format on save: ruff organise imports, then ruff format.
- `uv run <cmd>` runs inside the project's environment; `uv add <pkg>` adds a dependency.
- Enable/disable: `rig module enable lang-python` / `rig module disable lang-python`.
