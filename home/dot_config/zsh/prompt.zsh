# Prompt: user, directory, git branch with a dirty marker (built-in vcs_info).
# Colours come from theme.zsh (RIG_PROMPT_*), defined once in theme.yaml.

autoload -Uz vcs_info add-zsh-hook
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' unstagedstr '*'
zstyle ':vcs_info:git:*' stagedstr '+'
zstyle ':vcs_info:git:*' formats ' (%b%u%c)'
zstyle ':vcs_info:git:*' actionformats ' (%b|%a%u%c)'
add-zsh-hook precmd vcs_info

# srv: show mounted servers ( ⇅ ops-server, or ⇅ 3). Reads srv's state file,
# which lives in a runtime folder cleared when the mounts go away.
if [[ $OSTYPE == darwin* ]]; then _srv_state="${TMPDIR:-/tmp}/srv/mounted"
else _srv_state="${XDG_RUNTIME_DIR:-/tmp/srv-$UID}/srv/mounted"; fi
_srv_prompt() {
  SRV_SEG=''
  [[ -s $_srv_state ]] || return 0
  local -a m=(${(f)"$(<$_srv_state)"})
  (( ${#m} )) || return 0
  if (( ${#m} == 1 )); then SRV_SEG=" %F{yellow}⇅ ${m[1]}%f"; else SRV_SEG=" %F{yellow}⇅ ${#m}%f"; fi
}
add-zsh-hook precmd _srv_prompt

: ${RIG_PROMPT_FG:=223} ${RIG_PROMPT_BG1:=236} ${RIG_PROMPT_BG2:=237}
PROMPT="%K{$RIG_PROMPT_BG1}%F{$RIG_PROMPT_FG} %n %f%k%K{$RIG_PROMPT_BG2}%F{$RIG_PROMPT_FG} %~%f%k"'${vcs_info_msg_0_}${SRV_SEG}'" %F{$RIG_PROMPT_FG}>%f "
