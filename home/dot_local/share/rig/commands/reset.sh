# shellcheck shell=bash
# commands/reset.sh: rig reset <part>: rebuild a part that misbehaves. Your
# files, keys and history are never touched. A module offers <module>_reset.

cmd_reset() {
  load_machine
  local part=${1:-}; (($#)) && shift
  case $part in
    zsh) shell_reset ;;
    mason) nvim_reset mason ;;
    chezmoi) chezmoi_reset ;;
    all) shell_reset; nvim_reset; chezmoi_reset ;;
    *)
      if [[ -n $part ]] && module_exists "$part" && module_has "$part" reset; then "$(module_fn "$part" reset)" "$@"
      else die "usage: rig reset nvim|mason|zsh|chezmoi|all"; fi ;;
  esac
  ok "reset $part"
}

chezmoi_reset() {
  confirm "Clear chezmoi's script state so every setup script runs again on the next apply?" || return 0
  chezmoi state delete-bucket --bucket=scriptState
  chezmoi state delete-bucket --bucket=entryState
  chezmoi apply
}
