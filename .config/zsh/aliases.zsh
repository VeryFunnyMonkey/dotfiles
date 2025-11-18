# shell aliases
alias ls="ls --color=auto"

# Aliases based on MY_OS
case "$MY_OS" in
  macos)
    alias update="brew update && brew upgrade"
    ;;

  arch)
    alias update="yay -Syu"
    ;;

  fedora)
    alias update="sudo dnf upgrade --refresh"
    ;;

  debian)
    alias update="sudo apt update && sudo apt upgrade"
    ;;

  *)
    alias update="echo 'No update command for $MY_OS'"
    ;;
esac
