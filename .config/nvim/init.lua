vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.mouse = "a"
vim.opt.winborder="rounded"
vim.opt.ignorecase = true
vim.opt.clipboard = "unnamedplus"

-- unbind arrow keys (while learning)
vim.keymap.set({'n', 'v', 'i', 'c'}, '<Up>', '<Nop>')
vim.keymap.set({'n', 'v', 'i', 'c'}, '<Down>', '<Nop>')
vim.keymap.set({'n', 'v', 'i', 'c'}, '<Left>', '<Nop>')
vim.keymap.set({'n', 'v', 'i', 'c'}, '<Right>', '<Nop>')

require("config.lazy")
