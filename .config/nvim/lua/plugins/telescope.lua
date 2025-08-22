return {
  {
    'nvim-telescope/telescope.nvim',
    tag = '0.1.8',
    dependencies = { 
      'nvim-lua/plenary.nvim',
      { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' }
    },
    config = function()
      -- <leader>f to find files
      vim.keymap.set('n', '<leader>f', require('telescope.builtin').find_files, { noremap = true, silent = true })
    end
  }
}
