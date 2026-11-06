# PATH for every zsh. Sourced from ~/.zshenv (all shells, including the
# non-login shells most Linux terminals start) and again from .zprofile,
# because macOS's /etc/zprofile (path_helper) reorders PATH at login.
typeset -U path PATH

# Homebrew (macOS, Homebrew on Linux), without running `brew shellenv`
for _p in /opt/homebrew /usr/local/Homebrew /home/linuxbrew/.linuxbrew; do
  if [[ -x $_p/bin/brew ]]; then
    [[ $_p == /usr/local/Homebrew ]] && _p=/usr/local
    export HOMEBREW_PREFIX=$_p
    path=("$_p/bin" "$_p/sbin" $path)
    [[ -d $_p/share/man ]] && export MANPATH="$_p/share/man${MANPATH+:$MANPATH}:"
    break
  fi
done
unset _p

path=("$HOME/.local/bin" $path)
