local treesitter = require("nvim-treesitter")

local langs = { 
  "c", "lua", "vim", "vimdoc", "query", "python", 
  "javascript", "typescript", "c_sharp" 
}

treesitter.install(langs)

vim.api.nvim_create_autocmd('FileType', {
  pattern = langs,
  callback = function()
    vim.treesitter.start()
    vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end,
})
