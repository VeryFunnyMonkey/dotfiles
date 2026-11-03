-- Neovim 0.12+. Plugins via the built-in vim.pack (lockfile: nvim-pack-lock.json,
-- committed). Structure:
--   lua/config/   options, keymaps, autocmds, pack (plugin list), modules (rendered)
--   lua/plugins/  one file per plugin's setup

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

require("config.options")
require("config.pack")
require("config.keymaps")
require("config.autocmds")
