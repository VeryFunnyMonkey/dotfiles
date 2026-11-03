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

: ${RIG_PROMPT_FG:=223} ${RIG_PROMPT_BG1:=236} ${RIG_PROMPT_BG2:=237}
PROMPT="%K{$RIG_PROMPT_BG1}%F{$RIG_PROMPT_FG} %n %f%k%K{$RIG_PROMPT_BG2}%F{$RIG_PROMPT_FG} %~%f%k"'${vcs_info_msg_0_}'" %F{$RIG_PROMPT_FG}>%f "
