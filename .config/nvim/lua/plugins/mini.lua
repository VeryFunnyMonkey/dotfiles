require('mini.icons').setup()
require('mini.comment').setup()
require('mini.pairs').setup()
require('mini.files').setup()

vim.keymap.set("n", "<leader>e", function()
  local mf = require('mini.files')
  if not mf.close() then 
    mf.open(vim.api.nvim_buf_get_name(0)) 
  end
end, { desc = "toggle explorer" })
