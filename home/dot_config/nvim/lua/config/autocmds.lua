local au = vim.api.nvim_create_autocmd
local group = vim.api.nvim_create_augroup("config", { clear = true })

au("TextYankPost", {
  group = group,
  desc = "Highlight yanked text",
  callback = function() vim.hl.on_yank() end,
})

au("BufReadPost", {
  group = group,
  desc = "Restore the last cursor position",
  callback = function(args)
    local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
    local lines = vim.api.nvim_buf_line_count(args.buf)
    if mark[1] > 0 and mark[1] <= lines and vim.bo[args.buf].filetype ~= "gitcommit" then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Reload files changed outside nvim (an agent, a formatter, git checkout).
-- tmux focus-events makes switching panes count as focus.
au({ "FocusGained", "BufEnter", "CursorHold", "TermLeave" }, {
  group = group,
  desc = "Reload files changed on disk",
  callback = function()
    if vim.fn.mode() ~= "c" and vim.fn.getcmdwintype() == "" then vim.cmd.checktime() end
  end,
})

au("FileType", {
  group = group,
  pattern = { "markdown", "text", "gitcommit" },
  desc = "Wrap prose",
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
  end,
})

au("FileType", {
  group = group,
  pattern = { "help", "qf", "checkhealth", "man", "grug-far", "nvim-pack" },
  desc = "q closes helper windows",
  callback = function(args)
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = args.buf, silent = true, desc = "Close" })
  end,
})

-- First run on this machine: point at the course and the key search, once.
au("VimEnter", {
  group = group,
  desc = "Welcome hint (once per machine)",
  callback = function()
    if #vim.api.nvim_list_uis() == 0 then return end
    local marker = vim.fn.stdpath("state") .. "/dotfiles-welcome-shown"
    if vim.uv.fs_stat(marker) then return end
    vim.fn.mkdir(vim.fn.stdpath("state"), "p")
    vim.fn.writefile({}, marker)
    vim.defer_fn(function()
      vim.notify(
        "New here? :Tutor dotfiles walks through this setup.\n"
          .. "<Space> shows what you can press next; <Space>fk searches every key.",
        vim.log.levels.INFO,
        { title = "dotfiles" }
      )
    end, 500)
  end,
})
