# shellcheck shell=bash
# commands/doctor.sh: rig doctor. The machine and the dotfiles here; every
# module reports its own part (<module>_doctor).

cmd_doctor() {
  load_machine
  DOCTOR_FAILS=0
  info "machine: $RIG_PLATFORM$( [[ $RIG_WSL == true ]] && printf ' (WSL)') · ${RIG_DESKTOP:-no desktop} · profile ${RIG_PROFILE:-none}"
  say "  selected: ${RIG_SELECTED:-nothing beyond core}"
  if [[ -n $RIG_SKIPPED ]]; then say "  ${DIM}skipped here: $RIG_SKIPPED${N}"; fi

  info "dotfiles"
  if have chezmoi; then
    if [[ -z $(chezmoi status --exclude=scripts 2>/dev/null || true) ]]; then check_ok "chezmoi: everything applied"
    else check_bad "chezmoi: pending changes (rig diff / chezmoi apply)"; fi
  else check_bad "chezmoi not installed"; fi
  moved_aside
  wsl_systemd

  pkg_doctor
  modules_run doctor
  stack_review_due

  if ((DOCTOR_FAILS)); then say; say "${Y}$DOCTOR_FAILS problem(s)${N}"; return 1; fi
  say; say "${G}all good${N}"
}

# Your files rig moved aside when it took over (not a problem: where they are).
moved_aside() {
  local list; list=$(backup_paths | awk '{printf "%s~/%s", (NR > 1 ? ", " : ""), $0}')
  [[ -n $list ]] || return 0
  say "  ${DIM}yours, moved aside when rig took over: $list (in ${RIG_STATE/#$HOME/\~}/backup; rig uninstall puts them back)${N}"
}

# WSL can run systemd (one setting; new distros have it on). Without it the
# SSH agent and Podman's socket can't start on their own.
wsl_systemd() {
  is_windows && ! have_system_systemd || return 0
  info "WSL"
  check_bad "systemd is off in this distro: the SSH agent's socket and Podman's can't start on their own"
  say "  to turn it on: printf '\\n[boot]\\nsystemd=true\\n' | sudo tee -a /etc/wsl.conf"
  say "  (or add systemd=true under an existing [boot] in /etc/wsl.conf); then, in PowerShell:"
  say "  wsl --shutdown, open a new terminal, and: rig modules sync ssh-agent containers"
}

# The stack review (AGENTS.md): due 90 days after docs/stack.yaml's last_reviewed.
stack_review_due() {
  local f; f="$(repo_root)/docs/stack.yaml"
  [[ -f $f ]] || return 0
  local d; d=$(sed -n 's/^last_reviewed: *//p' "$f")
  [[ -n $d ]] || return 0
  local then_s now_s
  then_s=$(date -d "$d" +%s 2>/dev/null || date -j -f %Y-%m-%d "$d" +%s 2>/dev/null) || return 0
  now_s=$(date +%s)
  if (( (now_s - then_s) / 86400 > 90 )); then
    info "upkeep"
    say "  ${Y}!${N} stack review due (last: $d): ask your agent to do the stack review in AGENTS.md"
  fi
}
