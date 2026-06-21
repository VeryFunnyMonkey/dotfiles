require("mason").setup()
require("mason-lspconfig").setup({
  ensure_installed = { "lua_ls", "pyright", "ts_ls", "omnisharp", "efm" },
})

vim.lsp.config["*"] = {
  capabilities = require("blink.cmp").get_lsp_capabilities(),
}

vim.lsp.config("lua_ls", {})
vim.lsp.config("pyright", {})
vim.lsp.config("ts_ls", {})
vim.lsp.config("omnisharp", {})

local stylua = require("efmls-configs.formatters.stylua")
local black = require("efmls-configs.formatters.black")
local prettier_d = require("efmls-configs.formatters.prettier_d")

vim.lsp.config("efm", {
  init_options = { documentFormatting = true },
  settings = {
    languages = {
      lua = { stylua },
      python = { black },
      javascript = { prettier_d },
      typescript = { prettier_d },
    },
  },
})

vim.lsp.enable({
  "lua_ls",
  "pyright",
  "ts_ls",
  "omnisharp",
  "efm",
})

vim.api.nvim_create_autocmd("BufWritePre", {
  callback = function(args)
    pcall(vim.lsp.buf.format, {
      bufnr = args.buf,
      filter = function(c) return c.name == "efm" end,
    })
  end,
})

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local opts = { buffer = args.buf }
    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
    vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
    vim.keymap.set("n", "<leader>gd", function() require("fzf-lua").lsp_definitions({ jump_to_single_result = true }) end, opts)
    vim.keymap.set("n", "<leader>fr", function() require("fzf-lua").lsp_references() end, opts)
    vim.keymap.set("n", "<leader>ft", function() require("fzf-lua").lsp_typedefs() end, opts)
    vim.keymap.set("n", "<leader>fs", function() require("fzf-lua").lsp_document_symbols() end, opts)
    vim.keymap.set("n", "<leader>fw", function() require("fzf-lua").lsp_workspace_symbols() end, opts)
    vim.keymap.set("n", "<leader>fi", function() require("fzf-lua").lsp_implementations() end, opts)
    vim.keymap.set("n", "<leader>d", function() vim.diagnostic.open_float({ scope = "cursor" }) end, opts)
    vim.keymap.set("n", "<leader>D", function() vim.diagnostic.open_float({ scope = "line" }) end, opts)
    vim.keymap.set("n", "<leader>nd", vim.diagnostic.goto_next, opts)
    vim.keymap.set("n", "<leader>pd", vim.diagnostic.goto_prev, opts)
    vim.keymap.set("n", "<leader>q", function() vim.diagnostic.setloclist({ open = true }) end, opts)
  end,
})
