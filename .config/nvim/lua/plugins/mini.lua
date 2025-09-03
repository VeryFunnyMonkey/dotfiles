return {
  'echasnovski/mini.nvim',
  version = false,
  config = function()
    require('mini.pick').use_icons
    :require('mini.files').setup()
    require('mini.statusline').setup({
      use_icons = true,
      set_vim_settings = true,
})

    vim.keymap.set('n', '<leader>f', '<Cmd>Pick files<CR>', { desc = 'Find Files' })
    vim.keymap.set('n', '<leader>s', '<Cmd>Pick grep_live<CR>', { desc = 'Search Word (Grep)' })
    vim.keymap.set('n', '<leader>h', '<Cmd>Pick help<CR>', { desc = 'Help' })

    vim.keymap.set("n", "<leader>e", function()
      if not MiniFiles.close() then
    MiniFiles.open(vim.api.nvim_buf_get_name(0))
      end
    end, { desc = "Toggle file explorer" })


  end,
}
