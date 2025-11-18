# default programs
export EDITOR=nvim
export VISUAL=$EDITOR

# XDG base directories
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"

# Detect OS and set MY_OS
case "$OSTYPE" in
  darwin*)
    export MY_OS="macos"
    ;;

  linux*)
    # Read /etc/os-release for distro
    if [[ -f /etc/os-release ]]; then
      source /etc/os-release
      case "$ID" in
        arch)
          export MY_OS="arch"
          ;;
        fedora)
          export MY_OS="fedora"
          ;;
        ubuntu|debian)
          export MY_OS="debian"
          ;;
        *)
          export MY_OS="linux-unknown"
          ;;
      esac
    else
      export MY_OS="linux-unknown"
    fi
    ;;

  *)
    export MY_OS="unknown"
    ;;
esac

# brew setup (if on mac)
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# fnm
if [ -d "$XDG_DATA_HOME/fnm" ]; then
  export PATH="$XDG_DATA_HOME/fnm:$PATH"
fi

if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd)"
fi

# .NET global tools
export PATH="$HOME/.dotnet/tools:$PATH"
