detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        export MY_OS="macos"
    elif [[ -f /etc/os-release ]]; then
        source /etc/os-release
        case "$ID" in
            arch) export MY_OS="arch" ;;
            fedora) export MY_OS="fedora" ;;
            ubuntu|debian) export MY_OS="debian" ;;
            *) export MY_OS="linux-unknown" ;;
        esac
    else
        export MY_OS="unknown"
    fi
}

install() {
  if [[ $# -eq 0 ]]; then
    echo "Usage: install <package> [package...]"
    return 1
  fi

  case "$MY_OS" in
    macos)
      brew install "$@"
      ;;
    arch)
      yay -S "$@"
      ;;
    fedora)
      sudo dnf install "$@"
      ;;
    debian)
      sudo apt install "$@"
      ;;
    *)
      echo "No install command for $MY_OS"
      return 1
      ;;
  esac
}

update() {
  case "$MY_OS" in
    macos)
      brew update && brew upgrade
      ;;
    arch)
      yay -Syu
      ;;
    fedora)
      sudo dnf upgrade --refresh
      ;;
    debian)
      sudo apt update && sudo apt upgrade
      ;;
    *)
      echo "No update command for $MY_OS"
      return 1
      ;;
  esac

  if command -v flatpak >/dev/null 2>&1; then
    echo "Updating Flatpak apps and runtimes..."
    flatpak update -y
  else
    echo "Flatpak not installed, skipping Flatpak updates."
  fi
}

remove() {
  if [[ $# -eq 0 ]]; then
    echo "Usage: remove <package> [package...]"
    return 1
  fi

  case "$MY_OS" in
    macos)
      brew uninstall "$@"
      ;;
    arch)
      yay -Rns "$@"
      ;;
    fedora)
      sudo dnf remove "$@"
      ;;
    debian)
      sudo apt remove "$@"
      ;;
    *)
      echo "No remove command for $MY_OS"
      return 1
      ;;
  esac
}

search() {
  if [[ $# -eq 0 ]]; then
    echo "Usage: search <query>"
    return 1
  fi

  case "$MY_OS" in
    macos)
      brew search "$@"
      ;;
    arch)
      yay -Ss "$@"
      ;;
    fedora)
      dnf search "$@"
      ;;
    debian)
      apt search "$@"
      ;;
    *)
      echo "No search command for $MY_OS"
      return 1
      ;;
  esac
}
