local o = vim.opt

o.number = true
o.relativenumber = true
o.cursorline = true
o.signcolumn = "yes"
o.scrolloff = 8
o.wrap = false
o.breakindent = true
o.list = true
o.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

o.expandtab = true
o.shiftwidth = 2
o.tabstop = 2
o.softtabstop = 2

o.ignorecase = true
o.smartcase = true
o.inccommand = "split"

o.splitright = true
o.splitbelow = true
o.mouse = "a"
o.winborder = "rounded"
o.termguicolors = true
o.confirm = true
o.undofile = true
o.updatetime = 250
o.autoread = true

-- System clipboard, set after startup (the provider check is slow). On WSL,
-- Neovim picks win32yank.exe up from PATH by itself.
vim.schedule(function()
  o.clipboard = "unnamedplus"
end)

vim.diagnostic.config({
  severity_sort = true,
  virtual_text = { spacing = 2, source = "if_many" },
  float = { border = "rounded", source = "if_many" },
  signs = true,
  underline = true,
})
