# Aliases. Standard commands keep their names except ls; use rg, fd and bat
# by name so scripts and habits still work on machines without these dotfiles.

alias vim=nvim vi=nvim v=nvim

if (( $+commands[eza] )); then
  alias ls='eza --group-directories-first'
  alias ll='eza -l --git --group-directories-first'
  alias la='eza -la --git --group-directories-first'
  alias lt='eza --tree --level=2 --group-directories-first'
else
  if [[ $OSTYPE == darwin* ]]; then alias ls='ls -G'; else alias ls='ls --color=auto'; fi
  alias ll='ls -lh' la='ls -lAh'
fi

alias grep='grep --color=auto'

# Debian names some tools differently when installed from apt.
(( ! $+commands[bat] && $+commands[batcat] )) && alias bat=batcat
(( ! $+commands[fd] && $+commands[fdfind] )) && alias fd=fdfind

alias update='rig update'

# yazi: cd to wherever you quit it
if (( $+commands[yazi] )); then
  y() {
    local tmp cwd
    tmp="$(mktemp -t yazi-cwd.XXXXXX)"
    yazi "$@" --cwd-file="$tmp"
    IFS= read -r -d '' cwd < "$tmp"
    [[ -n $cwd && $cwd != "$PWD" ]] && builtin cd -- "$cwd"
    rm -f -- "$tmp"
  }
fi

# Podman (the containers item): DOCKER_HOST points at its Docker-compatible
# socket, and on macOS `docker` runs podman (Linux gets a real shim package).
if [[ -r ${XDG_STATE_HOME:-$HOME/.local/state}/rig/docker-host ]] && (( $+commands[podman] )); then
  export DOCKER_HOST="$(<${XDG_STATE_HOME:-$HOME/.local/state}/rig/docker-host)"
  (( $+commands[docker] )) || alias docker=podman
fi
