return {
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-tree").setup({
        disable_netrw = true,
        hijack_netrw = true,
        hijack_cursor = true,
        update_cwd = true,
        diagnostics = {
          enable = true,
          show_on_dirs = true,
        },
        view = {
          width = 30,
          side = "left",
       },
        git = {
          enable = true,
          ignore = false,
        },
      })
      
      -- <leader>e to toggle nvim-tree
      vim.keymap.set('n', '<leader>e', ':NvimTreeToggle<CR>', { noremap = true, silent = true })

    end
  }
}

