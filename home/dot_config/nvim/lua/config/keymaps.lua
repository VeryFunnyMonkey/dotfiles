-- General keymaps. Plugin keymaps live with their plugin (lua/plugins/*.lua).
-- Groups (each has a mini.clue label):
--   <leader>f find · <leader>c code · <leader>g git · <leader>s search/replace
--   <leader>u UI toggles · <leader>e / <leader>E explorer
local map = vim.keymap.set

-- Arrows off in normal/visual mode only: hjkl practice. They still work in
-- insert and command-line mode (command history needs Up/Down).
for _, key in ipairs({ "<Up>", "<Down>", "<Left>", "<Right>" }) do
  map({ "n", "x" }, key, "<Nop>")
end

map("n", "<Esc>", "<cmd>nohlsearch<cr><Esc>", { desc = "Clear search highlight" })
map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, desc = "Down (screen line)" })
map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, desc = "Up (screen line)" })
map("x", "<", "<gv", { desc = "Indent left, keep selection" })
map("x", ">", ">gv", { desc = "Indent right, keep selection" })

-- UI toggles
map("n", "<leader>uw", function() vim.wo.wrap = not vim.wo.wrap end, { desc = "Toggle wrap" })
map("n", "<leader>un", function() vim.wo.relativenumber = not vim.wo.relativenumber end,
  { desc = "Toggle relative numbers" })
map("n", "<leader>ud", function()
  local cfg = vim.diagnostic.config() or {}
  vim.diagnostic.config({ virtual_text = not cfg.virtual_text and { spacing = 2, source = "if_many" } or false })
end, { desc = "Toggle inline diagnostics" })

-- Diagnostics
map("n", "<leader>cl", function() vim.diagnostic.open_float({ scope = "line" }) end,
  { desc = "Line diagnostics" })

-- lazygit in a floating terminal (prefix g does the same from tmux)
map("n", "<leader>gg", function()
  require("config.float").term({ "lazygit" }, { on_exit = vim.cmd.checktime })
end, { desc = "lazygit" })
