-- Formatting on save. Formatters per filetype come from the enabled modules.
local conform = require("conform")
conform.setup({
  formatters_by_ft = require("config.modules").formatters,
  default_format_opts = { lsp_format = "fallback" },
  format_on_save = function(buf)
    if vim.b[buf].disable_autoformat or vim.g.disable_autoformat then return end
    -- YAML and Markdown: format on demand (<leader>cf) only, so existing repos
    -- (Ansible, Compose, docs) don't get reformatted just by saving
    local ft = vim.bo[buf].filetype
    if ft:match("^yaml") or ft == "markdown" then return end
    return { timeout_ms = 1000 }
  end,
})

vim.keymap.set({ "n", "x" }, "<leader>cf", function() conform.format({ async = true }) end,
  { desc = "Format" })
vim.keymap.set("n", "<leader>uf", function()
  vim.g.disable_autoformat = not vim.g.disable_autoformat
  vim.notify("Format on save " .. (vim.g.disable_autoformat and "off" or "on"))
end, { desc = "Toggle format on save" })
