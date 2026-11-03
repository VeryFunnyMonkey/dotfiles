-- Plugin list. vim.pack installs anything missing on startup; versions are
-- pinned in nvim-pack-lock.json. Update with `rig update` (or
-- :lua vim.pack.update()).

-- Rebuild treesitter parsers whenever nvim-treesitter itself changes.
vim.api.nvim_create_autocmd("PackChanged", {
  callback = function(ev)
    local name, kind = ev.data.spec.name, ev.data.kind
    if name == "nvim-treesitter" and kind == "update" then
      if not ev.data.active then vim.cmd.packadd("nvim-treesitter") end
      vim.cmd("TSUpdate")
    end
  end,
})

vim.pack.add({
  "https://github.com/ellisonleao/gruvbox.nvim",
  "https://github.com/nvim-mini/mini.nvim",
  "https://github.com/ibhagwan/fzf-lua",
  { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },
  { src = "https://github.com/saghen/blink.cmp", version = vim.version.range("1.*") },
  "https://github.com/mason-org/mason.nvim",
  "https://github.com/mason-org/mason-lspconfig.nvim",
  "https://github.com/neovim/nvim-lspconfig",
  "https://github.com/stevearc/conform.nvim",
  "https://github.com/MagicDuck/grug-far.nvim",
  "https://github.com/christoomey/vim-tmux-navigator",
}, { confirm = false })

for _, name in ipairs({
  "theme",
  "mini",
  "fzf",
  "treesitter",
  "blink",
  "lsp",
  "conform",
  "grug-far",
}) do
  local ok, err = pcall(require, "plugins." .. name)
  if not ok then
    vim.notify(("plugins.%s failed to load:\n%s"):format(name, err), vim.log.levels.ERROR)
  end
end
