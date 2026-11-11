-- Neovim 0.12+. Plugins via the built-in vim.pack (lockfile: nvim-pack-lock.json,
-- committed). Structure:
--   lua/config/   options, keymaps, autocmds, pack (plugin list), modules (rendered),
--                 float (float.term: a program in a floating terminal)
--   lua/plugins/  one file per plugin's setup

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Each part loads on its own, so one broken or missing file reports an error
-- instead of leaving you with no config at all.
for _, mod in ipairs({ "config.options", "config.filetypes", "config.pack", "config.keymaps", "config.autocmds" }) do
  local ok, err = pcall(require, mod)
  if not ok then vim.notify(("%s failed to load:\n%s"):format(mod, err), vim.log.levels.ERROR) end
end

-- This machine's own additions (not in the repo): ~/.config/nvim/lua/local.lua
local here = vim.fn.stdpath("config") .. "/lua/local.lua"
if vim.uv.fs_stat(here) then
  local ok, err = pcall(dofile, here)
  if not ok then vim.notify(("local.lua failed to load:\n%s"):format(err), vim.log.levels.ERROR) end
end
