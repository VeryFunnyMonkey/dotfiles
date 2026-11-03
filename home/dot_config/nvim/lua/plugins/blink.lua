-- Completion. Keys are Vim's own: C-n / C-p move (or open the menu),
-- C-y or Enter accept, C-e dismiss. (C-Space is tmux's prefix.)
require("blink.cmp").setup({
  keymap = {
    preset = "none",
    ["<C-n>"] = { "select_next", "show", "fallback" },
    ["<C-p>"] = { "select_prev", "show", "fallback" },
    ["<C-y>"] = { "accept", "fallback" },
    ["<CR>"] = { "accept", "fallback" },
    ["<C-e>"] = { "hide", "fallback" },
    ["<C-b>"] = { "scroll_documentation_up", "fallback" },
    ["<C-f>"] = { "scroll_documentation_down", "fallback" },
    ["<Tab>"] = { "snippet_forward", "fallback" },
    ["<S-Tab>"] = { "snippet_backward", "fallback" },
  },
  appearance = { nerd_font_variant = "mono" },
  completion = { documentation = { auto_show = true, auto_show_delay_ms = 300 } },
  signature = { enabled = true },
  sources = { default = { "lsp", "path", "buffer", "snippets" } },
  fuzzy = { implementation = "prefer_rust" },
})
