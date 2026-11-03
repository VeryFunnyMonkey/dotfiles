-- nvim-treesitter (main branch): installs parsers; highlighting is Neovim's own.
local parsers = require("config.modules").parsers
require("nvim-treesitter").install(parsers)

-- Start highlighting for any filetype that has a parser. Neovim maps filetype
-- to parser name itself (help -> vimdoc, cs -> c_sharp ...), which is why this
-- uses FileType * rather than a list of parser names.
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("treesitter-start", { clear = true }),
  callback = function(args)
    if pcall(vim.treesitter.start, args.buf) then
      vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end
  end,
})
