# shellcheck shell=bash
# modules/nvim.sh: Neovim's plugins (from the committed lockfile), treesitter
# parsers and Mason tools. The config itself is plain files from the repo.

# The toolchains Mason's servers need (Node for npm ones, Go, Rust), on PATH.
nvim_env() {
  brew_env
  with_node
  export GOPATH="$DATA_HOME/go" RUSTUP_HOME="$DATA_HOME/rustup" CARGO_HOME="$DATA_HOME/cargo"
  PATH="$CARGO_HOME/bin:$GOPATH/bin:$HOME/.local/bin:$PATH"
}
nvim_bootstrap() { nvim_env; nvim --headless "+lua require('config.bootstrap').run()" +qa; }

nvim_sync() {
  have nvim || { warn "nvim not installed yet; skipping"; return 0; }
  info "setting up neovim (plugins, parsers, language tools)"
  nvim_bootstrap
}

nvim_update() {
  have nvim || return 0
  info "neovim plugins and Mason tools"
  nvim_env
  local how=''
  if [[ ${RIG_UPDATE_PLUGINS:-0} == 1 ]]; then how='{latest = true}'; fi
  nvim --headless "+lua require('config.bootstrap').update($how)" +qa 2>&1 | tail -n 20 || warn "nvim update had errors"
  if [[ -n $(git -C "$(repo_root)" status --porcelain -- home/dot_config/nvim/nvim-pack-lock.json 2>/dev/null) ]]; then
    say "  ${DIM}nvim-pack-lock.json changed (plugin updates); commit it to pin them on every machine${N}"
  fi
}

nvim_doctor() {
  info "neovim"
  if ! have nvim; then check_bad "nvim not installed"; return 0; fi
  local v; v=$(nvim --version | head -1)
  if nvim --headless -c 'lua if vim.fn.has("nvim-0.12") == 0 then vim.cmd("cq") end' -c qa >/dev/null 2>&1; then check_ok "$v"
  else check_bad "$v (0.12+ needed)"; fi
  local errs; errs=$(nvim --headless "+checkhealth vim.lsp vim.treesitter mason" "+w! /dev/stdout" +qa 2>/dev/null | grep -c '❌ ERROR' || true)
  if [[ ${errs:-0} == 0 ]]; then check_ok "checkhealth: no errors"; else check_bad "checkhealth: $errs errors (run :checkhealth in nvim)"; fi
}

nvim_reset() { # [mason]: only the Mason tools
  if [[ ${1:-} == mason ]]; then
    confirm "Reset Mason tools?" || return 0
    rm -rf "$DATA_HOME/nvim/mason"
  else
    confirm "Reset nvim plugins, parsers and Mason tools (your undo history and settings stay)?" || return 0
    rm -rf "$DATA_HOME/nvim/site/pack/core" "$DATA_HOME/nvim/site/parser" "$DATA_HOME/nvim/site/queries" "$DATA_HOME/nvim/mason"
  fi
  nvim_bootstrap
}

# Plugins, parsers and tools go; your history, undo and sessions stay.
nvim_uninstall() {
  rm -rf "$DATA_HOME/nvim/site/pack/core" "$DATA_HOME/nvim/site/parser" "$DATA_HOME/nvim/site/parser-info" \
    "$DATA_HOME/nvim/site/queries" "$DATA_HOME/nvim/mason" "$CACHE_HOME/nvim/mason-registry-update" \
    "$CACHE_HOME/tree-sitter" "$STATE_HOME/nvim/lsp.log" "$STATE_HOME/nvim/mason.log" "$STATE_HOME/nvim/nvim.log"
}
