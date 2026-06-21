vim.pack.add({
  "https://github.com/echasnovski/mini.nvim",
  "https://github.com/ibhagwan/fzf-lua",
  "https://github.com/morhetz/gruvbox",
  "https://github.com/mason-org/mason.nvim",
  "https://github.com/williamboman/mason-lspconfig.nvim",
  "https://github.com/neovim/nvim-lspconfig",
  "https://github.com/L3MON4D3/LuaSnip",
  "https://github.com/creativenull/efmls-configs-nvim",
  "https://github.com/Saghen/blink.lib",
  {
    src = "https://github.com/nvim-treesitter/nvim-treesitter",
    branch = "main",
    build = ":TSUpdate",
  },
  {
    src = "https://github.com/saghen/blink.cmp",
    version = vim.version.range("1.*"),
  },
})

require("plugins.theme")
require("plugins.mini")
require("plugins.fzf")
require("plugins.treesitter")
require("plugins.blink")
require("plugins.lsp")
