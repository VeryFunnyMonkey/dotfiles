# shellcheck shell=bash
# commands/update.sh: rig update. The dotfiles, the packages, then every
# module's own update (<module>_update: agents, toolchains, nvim plugins).

cmd_update() {
  load_machine
  info "dotfiles (chezmoi update)"
  chezmoi update --refresh-externals=always || warn "chezmoi update failed"
  pkg_update
  modules_run update
  ok "updated"
}
