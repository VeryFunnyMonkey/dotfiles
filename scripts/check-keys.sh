#!/usr/bin/env bash
# Every <leader> key the tutor course and the README mention must exist in
# Neovim (so the docs can't drift from the config). Run by the pre-commit hook.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
keys=$(grep -ohE '<leader>[a-zA-Z/.<>]+' "$root/home/dot_config/nvim/tutor/dotfiles.tutor" "$root/README.md" |
  sed 's/<leader><space>.*/<leader><space>/' | sort -u)
# the README cheatsheet lists groups like "<leader>ff fg fw": expand them
keys+=$'\n'$(grep -oE '^\| `<leader>[a-z]+`( `[a-zA-Z/.]+`)+' "$root/README.md" |
  sed -E 's/^\| //' | tr -d '`' | awk '{for (i=2;i<=NF;i++) print "<leader>" $i}')
keys=$(sort -u <<<"$keys" | sed '/^$/d')
missing=$(nvim --headless -c "lua
  local missing = {}
  for k in ([[$keys]]):gmatch('[^\n]+') do
    local lhs = vim.keycode(k)
    local found = vim.fn.maparg(lhs, 'n') ~= '' or vim.fn.maparg(lhs, 'x') ~= ''
    -- a group prefix (<leader>f) is fine when real keys start with it
    if not found then
      local want = lhs:gsub(' ', '<Space>')
      for _, m in ipairs(vim.api.nvim_get_keymap('n')) do
        local l = m.lhs:gsub(' ', '<Space>')
        if #l > #want and l:sub(1, #want) == want then found = true break end
      end
    end
    -- LSP keys are buffer-local (set when a server attaches): accept them from lsp.lua
    if not found then
      local src = table.concat(vim.fn.readfile(vim.fn.stdpath('config') .. '/lua/plugins/lsp.lua'), '\n')
      found = src:find(k, 1, true) ~= nil
    end
    if not found then table.insert(missing, k) end
  end
  io.stdout:write(table.concat(missing, ' '))
" +qa 2>/dev/null)
if [[ -n $missing ]]; then
  echo "keys mentioned in the tutor/README but not mapped in nvim: $missing" >&2
  exit 1
fi
echo "keys: all $(wc -l <<<"$keys" | tr -d ' ') mentioned keys exist"
