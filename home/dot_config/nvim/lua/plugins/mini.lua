require("mini.icons").setup()
require("mini.pairs").setup()
require("mini.ai").setup()
require("mini.surround").setup()
require("mini.statusline").setup()
require("mini.diff").setup() -- signs; [h ]h move between hunks; gh / gH apply / reset
require("mini.files").setup()

local map = vim.keymap.set

map("n", "<leader>e", function()
  local mf = require("mini.files")
  if not mf.close() then
    local path = vim.api.nvim_buf_get_name(0)
    mf.open(vim.uv.fs_stat(path) and path or nil)
  end
end, { desc = "Explorer (at file)" })
map("n", "<leader>E", function()
  local mf = require("mini.files")
  if not mf.close() then mf.open(vim.uv.cwd()) end
end, { desc = "Explorer (cwd)" })

map("n", "<leader>go", function()
  local diff = require("mini.diff")
  if not diff.get_buf_data(0) then
    vim.notify("No diff here: this buffer isn't a file", vim.log.levels.WARN)
    return
  end
  diff.toggle_overlay(0)
end, { desc = "Diff overlay" })

-- mini.clue: press <leader>, g, [, ], z, <C-w>, ", ' or ` and wait for a menu of keys.
local clue = require("mini.clue")
clue.setup({
  window = { delay = 300, config = { width = "auto" } },
  triggers = {
    { mode = "n", keys = "<Leader>" }, { mode = "x", keys = "<Leader>" },
    { mode = "n", keys = "g" }, { mode = "x", keys = "g" },
    { mode = "n", keys = "[" }, { mode = "n", keys = "]" },
    { mode = "n", keys = "z" }, { mode = "x", keys = "z" },
    { mode = "n", keys = "<C-w>" },
    { mode = "n", keys = '"' }, { mode = "x", keys = '"' },
    { mode = "i", keys = "<C-r>" }, { mode = "c", keys = "<C-r>" },
    { mode = "n", keys = "'" }, { mode = "n", keys = "`" },
  },
  clues = {
    { mode = "n", keys = "<Leader>f", desc = "+find" },
    { mode = "n", keys = "<Leader>c", desc = "+code" },
    { mode = "n", keys = "<Leader>g", desc = "+git" },
    { mode = "n", keys = "<Leader>s", desc = "+search/replace" },
    { mode = "n", keys = "<Leader>u", desc = "+ui toggles" },
    clue.gen_clues.builtin_completion(),
    clue.gen_clues.g(),
    clue.gen_clues.marks(),
    clue.gen_clues.registers(),
    clue.gen_clues.windows(),
    clue.gen_clues.z(),
  },
})
