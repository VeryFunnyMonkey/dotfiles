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

  pkg_doctor
  modules_run doctor
  stack_review_due

  if ((DOCTOR_FAILS)); then say; say "${Y}$DOCTOR_FAILS problem(s)${N}"; return 1; fi
  say; say "${G}all good${N}"
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
