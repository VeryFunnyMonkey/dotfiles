-- Project-wide find & replace with a live preview.
local grug = require("grug-far")
grug.setup({})

vim.keymap.set("n", "<leader>sr", function() grug.open() end, { desc = "Replace in project" })
vim.keymap.set("n", "<leader>sw", function()
  grug.open({ prefills = { search = vim.fn.expand("<cword>") } })
end, { desc = "Replace word under cursor" })
vim.keymap.set("x", "<leader>sr", function() grug.with_visual_selection() end,
  { desc = "Replace selection in project" })
