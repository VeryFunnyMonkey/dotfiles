local fzf = require("fzf-lua")
fzf.setup({ "default-title", winopts = { border = "rounded" } })

local map = vim.keymap.set
map("n", "<leader><space>", fzf.combine and function() fzf.combine({ pickers = "buffers;oldfiles" }) end
  or fzf.oldfiles, { desc = "Recent & open files" })
map("n", "<leader>ff", fzf.files, { desc = "Files" })
map("n", "<leader>fg", fzf.live_grep, { desc = "Grep" })
map("n", "<leader>fw", fzf.grep_cword, { desc = "Grep word under cursor" })
map("n", "<leader>fb", fzf.buffers, { desc = "Buffers" })
map("n", "<leader>fr", fzf.oldfiles, { desc = "Recent files" })
map("n", "<leader>fh", fzf.helptags, { desc = "Help" })
map("n", "<leader>fk", fzf.keymaps, { desc = "Keymaps (search by description)" })
map("n", "<leader>f/", fzf.blines, { desc = "Lines in buffer" })
map("n", "<leader>f.", fzf.resume, { desc = "Resume last picker" })
map("n", "<leader>gs", fzf.git_status, { desc = "Changed files" })
