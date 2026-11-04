# shellcheck shell=bash
# commands/misc.sh: rig edit, rig help.

# ------------------------------------------------------------- edit etc -------
cmd_edit() {
  load_machine
  if (($#)); then chezmoi edit --apply "$@"
  else (cd "$(repo_root)" && "${EDITOR:-nvim}" .); chezmoi apply; fi
}

cmd_help() {
  cat <<EOF
${B}rig${N}: this machine's setup

  ${B}rig setup${N}                  the installer: pick software by category, review, install
  ${B}rig add${N} <item|pkg>         select a catalog item, or add an extra package for this machine
  ${B}rig remove${N} <item|pkg>      deselect it (uninstalls what rig installed for it)
  ${B}rig profile${N} list|show|use|save   saved selections (the presets)
  ${B}rig info${N} <item>            what an item brings (its guide)
  ${B}rig settings${N} [list|sync --dry-run]   the OS settings your selected items apply
  ${B}rig sync${N}                   install whatever is selected but missing
  ${B}rig search${N} <query>         search the package managers
  ${B}rig drift${N} [--all]          installed-but-undeclared, declared-but-missing
  ${B}rig update${N}                 update everything: dotfiles, packages, plugins
  ${B}rig doctor${N}                 check this machine
  ${B}rig git${N} add|list|which|remove|clone|doctor   git accounts (GitHub, GitLab, ...)
  ${B}rig agents${N} list|default <name>   coding agents (select them in rig setup)
  ${B}rig modules${N} list|sync <name>     the features rig sets up, and running one's setup again
  ${B}rig edit${N} [file]            edit the dotfiles (then apply)
  ${B}rig diff${N} / ${B}rig apply${N}        chezmoi diff / apply
  ${B}rig reset${N} nvim|mason|zsh|chezmoi|all   rebuild a part that misbehaves
  ${B}rig uninstall${N} [--packages --runtimes --identities --agents | --everything] [--run]
                             put the machine back as it was (dry run unless --run)
  ${B}rig uninstall --restore${N} <archive>   undo an uninstall
EOF
}
