-- float.term(cmd): run a program in a floating terminal that closes when it
-- exits. Out of terminal mode (a click, a focus change), keys reach nvim, not
-- the program: q still closes it, and coming back to the float types into it.
local M = {}

function M.term(cmd, opts)
  opts = opts or {}
  local buf = vim.api.nvim_create_buf(false, true)
  local w = math.floor(vim.o.columns * 0.9)
  local h = math.floor(vim.o.lines * 0.9)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor", width = w, height = h,
    col = math.floor((vim.o.columns - w) / 2), row = math.floor((vim.o.lines - h) / 2),
    style = "minimal",
  })
  local job = vim.fn.jobstart(cmd, {
    term = true,
    on_exit = function()
      if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
      if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
      if opts.on_exit then opts.on_exit() end
    end,
  })
  vim.keymap.set("n", "q", function() vim.fn.jobstop(job) end, { buffer = buf, desc = "Close" })
  vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained" }, {
    buffer = buf,
    callback = function()
      if vim.api.nvim_get_current_buf() == buf then vim.cmd.startinsert() end
    end,
  })
  vim.cmd.startinsert()
end

return M
