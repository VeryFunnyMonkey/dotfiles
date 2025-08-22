return {
  {
    "morhetz/gruvbox",
    config = function()
      -- Use dark or light mode
      vim.o.background = "dark"  -- "light" for light mode

      -- Enable termguicolors for true colors
      vim.o.termguicolors = true

      -- Set the colorscheme
      vim.cmd([[colorscheme gruvbox]])
    end
  }
}
