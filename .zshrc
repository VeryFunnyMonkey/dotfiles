# main zsh settings. env in ~/.zprofile
# this file is read after ~/.zprofile

# source global shell alias
[[ -f "$XDG_CONFIG_HOME/zsh/aliases.zsh" ]] && source "$XDG_CONFIG_HOME/zsh/aliases.zsh"

# load modules
autoload -U compinit && compinit
autoload -U colors && colors

# opts
setopt append_history      # Append to history file, don't overwrite
setopt share_history       # Share history between all running shells
setopt hist_ignore_dups    # Don't record duplicate commands
setopt hist_ignore_space   # Don't record commands starting with a space
setopt prompt_subst

# history config
HISTFILE="$XDG_CACHE_HOME/zsh_history"    # Where to store history
HISTSIZE=10000             # How many lines of history to keep in memory
SAVEHIST=10000             # How many lines of history to save to the file

# completion style
zstyle ':completion:*' menu select
zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete _correct _approximate
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'

# yazi helper function
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
	rm -f -- "$tmp"
}

# prompt config

PROMPT='%K{236}%F{223} %n %f%k%K{237}%F{223} %~ %f%k %F{223}>%f '

if [ -f "$XDG_CONFIG_HOME/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
  source "$XDG_CONFIG_HOME/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

