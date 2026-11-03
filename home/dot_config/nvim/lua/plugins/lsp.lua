-- Language servers: Mason installs them, mason-lspconfig enables them.
-- Which servers depends on the enabled modules (config/modules.lua).
local mods = require("config.modules")

require("mason").setup({ ui = { border = "rounded" } })
local headless = #vim.api.nvim_list_uis() == 0
require("mason-lspconfig").setup({
  -- headless runs (setup, `rig update`) install everything via config.bootstrap
  ensure_installed = headless and {} or mods.servers,
  -- only the servers we list; formatters like stylua also ship an LSP mode,
  -- which would otherwise start next to conform
  automatic_enable = mods.servers,
})

-- Keep the non-LSP Mason tools (formatters) installed too, in the background.
-- Headless runs (setup, `rig update`) do this themselves, synchronously.
local ok, registry = pcall(require, "mason-registry")
if ok and not headless then
  registry.refresh(function()
    for _, name in ipairs(mods.mason) do
      local found, pkg = pcall(registry.get_package, name)
      if found and not pkg:is_installed() and not pkg:is_installing() then pkg:install() end
    end
  end)
end

vim.lsp.config("*", { capabilities = require("blink.cmp").get_lsp_capabilities() })

-- Started directly: servers that don't come from Mason (rust-analyzer from rustup)
for _, name in ipairs(mods.system_servers or {}) do
  vim.lsp.enable(name)
end

vim.lsp.config("yamlls", {
  settings = {
    yaml = {
      -- schemas from schemastore.org: docker-compose, GitHub Actions, Ansible, ...
      schemaStore = { enable = true, url = "https://www.schemastore.org/api/json/catalog.json" },
      keyOrdering = false,
    },
  },
})
vim.lsp.config("gopls", { settings = { gopls = { staticcheck = true, gofumpt = true } } })
vim.lsp.config("rust_analyzer", {
  -- through rustup, so it always matches the toolchain (works with any rustup install)
  cmd = vim.fn.executable("rustup") == 1 and { "rustup", "run", "stable", "rust-analyzer" } or nil,
  settings = { ["rust-analyzer"] = { check = { command = "clippy" } } },
})

vim.lsp.config("lua_ls", {
  settings = {
    Lua = {
      runtime = { version = "LuaJIT" },
      diagnostics = { globals = { "vim" } },
      workspace = { checkThirdParty = false, library = { vim.env.VIMRUNTIME } },
      telemetry = { enable = false },
    },
  },
})

-- Neovim's built-in LSP keys still work: grn rename, gra action, grr references,
-- gri implementation, grt type definition, gO symbols, K hover, [d ]d diagnostics.
-- The <leader>c group adds fzf pickers and easier names.
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("lsp-keys", { clear = true }),
  callback = function(args)
    local fzf = require("fzf-lua")
    local function map(keys, fn, desc)
      vim.keymap.set("n", keys, fn, { buffer = args.buf, desc = desc })
    end
    map("<leader>cd", function() fzf.lsp_definitions({ jump1 = true }) end, "Definition")
    map("<leader>cr", fzf.lsp_references, "References")
    map("<leader>ci", fzf.lsp_implementations, "Implementations")
    map("<leader>ct", fzf.lsp_typedefs, "Type definition")
    map("<leader>cs", fzf.lsp_document_symbols, "Symbols (document)")
    map("<leader>cS", fzf.lsp_live_workspace_symbols, "Symbols (workspace)")
    map("<leader>ca", vim.lsp.buf.code_action, "Code action")
    map("<leader>cn", vim.lsp.buf.rename, "Rename")
    map("<leader>cx", fzf.diagnostics_document, "Diagnostics (document)")
    map("<leader>cX", fzf.diagnostics_workspace, "Diagnostics (workspace)")
  end,
})
