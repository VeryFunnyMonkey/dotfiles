vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.mouse = "a"
vim.opt.winborder = "rounded"
vim.opt.ignorecase = true
vim.opt.clipboard = "unnamedplus"

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- unbind arrow keys
vim.keymap.set({'n', 'v', 'i', 'c'}, '<Up>', '<Nop>')
vim.keymap.set({'n', 'v', 'i', 'c'}, '<Down>', '<Nop>')
vim.keymap.set({'n', 'v', 'i', 'c'}, '<Left>', '<Nop>')
vim.keymap.set({'n', 'v', 'i', 'c'}, '<Right>', '<Nop>')

-- statusline
function MyStatusLine()
  local mode = vim.api.nvim_get_mode().mode
  local file_name = vim.fn.expand('%:t')
  if file_name == '' then file_name = '[No Name]' end
  local modified = vim.bo.modified and " [+]" or ""
  
  -- [MODE] FileName [+] ========== Line:Col
  return string.format(" [%s] %s%s %%= %%l:%%c ", mode:upper(), file_name, modified)
end
vim.opt.statusline = "%!v:lua.MyStatusLine()"

-- load plugins with vim.pack
require("config.plugins")
