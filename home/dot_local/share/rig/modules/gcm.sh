# shellcheck shell=bash
# modules/gcm.sh: Git Credential Manager on Windows (the git-credential-manager
# item): git in WSL signs in through Windows (your Windows and work accounts,
# MSAL; Windows' credential store), as GCM's WSL guide recommends: Git for
# Windows' git-credential-manager.exe as git's credential helper.
# The settings go in ~/.config/git/local.gitconfig (machine-local; rig's git
# config includes it), each recorded first:
#   git-local  key: the setting   previous: its value before, or none
# and put back on undo.

GCM_SETTINGS=(credential.helper "credential.https://dev.azure.com.useHttpPath")
gitlocal_file() { printf '%s/git/local.gitconfig' "${XDG_CONFIG_HOME:-$HOME/.config}"; }

gcm_sync() {
  win_ready || return 0
  if module_active gcm; then gcm_setup; else gcm_teardown; fi
}

# git-credential-manager.exe from Git for Windows (per user or for everyone;
# its folder is ucrt64 from Git 2.56, mingw64 before, clangarm64 on ARM)
gcm_exe() {
  local l d p; l=$(win_env LOCALAPPDATA) || return 1
  for d in "$l/Programs/Git" "/mnt/c/Program Files/Git"; do
    for p in "$d"/{ucrt64,mingw64,clangarm64}/bin/git-credential-manager.exe; do
      if [[ -f $p ]]; then printf '%s' "$p"; return 0; fi
    done
  done
  return 1
}
# git runs a helper path through the shell: spaces and parentheses escaped
gcm_helper() { local h=$1; h=${h// /\\ }; h=${h//(/\\(}; h=${h//)/\\)}; printf '%s' "$h"; }

gitlocal_set() { # setting value... (several: a list, as git's credential.helper)
  local f cur want v; f=$(gitlocal_file)
  cur=$(git config -f "$f" --get-all "$1" 2>/dev/null || true)
  want=$(printf '%s\n' "${@:2}"); want=${want%$'\n'}
  [[ $cur == "$want" ]] && return 0
  if ! ledger_has git-local "$1"; then ledger_record git-local "$1" "$(git config -f "$f" --get "$1" 2>/dev/null || echo none)"; fi
  mkdir -p "$(dirname "$f")"
  git config -f "$f" --unset-all "$1" 2>/dev/null || true
  for v in "${@:2}"; do git config -f "$f" --add "$1" "$v"; done
}
revert_git_local() { # setting previous|none
  local f; f=$(gitlocal_file)
  [[ -f $f ]] || return 0
  git config -f "$f" --unset-all "$1" 2>/dev/null || true
  if [[ $2 != none ]]; then git config -f "$f" --add "$1" "$2"; fi
  # nothing left in it: rig made it, rig removes it
  if [[ -z $(git config -f "$f" --list 2>/dev/null) ]]; then rm -f "$f"; fi
}

gcm_setup() {
  local exe; exe=$(gcm_exe) || { warn "Git Credential Manager not found (Git for Windows isn't installed yet: rig sync)"; return 0; }
  # an empty helper first: git forgets the ones set before (an older
  # ~/.gitconfig's, say), so GCM is the only one asked
  gitlocal_set credential.helper "" "$(gcm_helper "$exe")"
  gitlocal_set "credential.https://dev.azure.com.useHttpPath" true   # Azure DevOps needs it (GCM's guide)
  ok "git signs in through Windows (Git Credential Manager)"
}

gcm_teardown() {
  local s; for s in "${GCM_SETTINGS[@]}"; do ledger_undo git-local "$s"; done
}

gcm_doctor() {
  module_active gcm && win_ready || return 0
  info "Git Credential Manager (Windows)"
  local h; h=$(git config --get-all credential.helper 2>/dev/null | tail -n1 || true)
  if [[ -z $h ]]; then check_bad "git has no credential helper (rig modules sync gcm)"
  elif [[ $h != *git-credential-manager.exe ]]; then check_ok "credential helper: $h (yours, not Windows' GCM)"
  elif [[ -f ${h//\\/} ]]; then check_ok "git signs in through Windows"
  else check_bad "the helper is gone (${h//\\/}; Git for Windows moved or was removed): rig modules sync gcm"; fi
}
