# Plugins and tool integrations. chezmoi fetches the plugins
# (.chezmoiexternal.toml, refreshed weekly); nothing is cloned into the repo.

_plugins="$XDG_DATA_HOME/zsh/plugins"

# fzf: Ctrl-R history, Ctrl-T files, Alt-C directories
if (( $+commands[fzf] )); then
  if (( $+commands[fd] )); then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
  fi
  (( $+commands[bat] )) && export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:200 {}'"
  if ! source <(fzf --zsh) 2>/dev/null; then
    # fzf older than 0.48 has no --zsh; use the distro's scripts
    for _f in /usr/share/fzf/key-bindings.zsh /usr/share/doc/fzf/examples/key-bindings.zsh; do
      [[ -r $_f ]] && source "$_f" && break
    done
  fi
fi

# zoxide: `z <part of a path>`
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"

# fnm (Node): switches version on cd when a project has .nvmrc/.node-version
(( $+commands[fnm] )) && eval "$(fnm env --use-on-cd --shell zsh)"

# zsh plugins; syntax highlighting must be last
[[ -r $_plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] &&
  source "$_plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
[[ -r $_plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] &&
  source "$_plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

unset _plugins _f
