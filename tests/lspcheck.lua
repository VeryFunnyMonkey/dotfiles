-- usage: nvim --headless -c "luafile lspcheck.lua" <file>; prints attached client names
vim.defer_fn(function()
  local names = {}
  for _, c in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do table.insert(names, c.name) end
  table.sort(names)
  io.stdout:write("ft=" .. vim.bo.filetype .. " clients=" .. table.concat(names, ",") .. "\n")
  vim.cmd("qa!")
end, tonumber(vim.env.WAIT or "15000"))
