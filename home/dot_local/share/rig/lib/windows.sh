# shellcheck shell=bash
# lib/windows.sh: reaching Windows from inside WSL (interop: cmd.exe,
# powershell.exe, reg.exe and the C: drive), for the Windows-side items
# (winterm, powertoys, glazewm). Every change goes in the ledger first:
#   win-file  key: a Linux path on the Windows drive   previous: a backup, or none
#   win-reg   key: HKCU\path|name                      previous: TYPE|data, or none
# A module undoes its own with win_file_restore / win_reg_restore; rig
# uninstall replays the rest through revert_win_file / revert_win_reg.

is_windows() { [[ ${RIG_WSL:-} == true ]] || grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; }
win_ready() { is_windows && have wslpath && [[ -n $(win_exe cmd.exe) ]]; }   # WSL with interop on

# A Windows program: on PATH (WSL appends Windows' PATH), else where Windows
# keeps it (a login through sudo -i, or appendWindowsPath=false, has no PATH).
WIN_SYS=${WIN_SYS:-/mnt/c/Windows/System32}
win_exe() { # name.exe -> its path
  if have "$1"; then command -v "$1"; return 0; fi
  local p
  case $1 in
    powershell.exe) p=$WIN_SYS/WindowsPowerShell/v1.0/powershell.exe ;;
    winget.exe|wt.exe) p="$(win_env LOCALAPPDATA)/Microsoft/WindowsApps/$1" ;;
    *) p=$WIN_SYS/$1 ;;
  esac
  if [[ -e $p ]]; then printf '%s' "$p"; else return 1; fi
}

# Windows programs run from a Windows folder (from a Linux one, cmd.exe warns
# about UNC paths); their output has CRLF line ends.
win_cmd() { local c; c=$(win_exe cmd.exe) || return 1; (cd /mnt/c 2>/dev/null || true; "$c" /d /c "$@" 2>/dev/null) | tr -d '\r'; }
win_ps() { local p; p=$(win_exe powershell.exe) || return 1; (cd /mnt/c 2>/dev/null || true; "$p" -NoProfile -NonInteractive -ExecutionPolicy Bypass "$@") | tr -d '\r'; }
win_reg() { local r; r=$(win_exe reg.exe) || return 1; (cd /mnt/c 2>/dev/null || true; "$r" "$@") | tr -d '\r'; }

# A Windows folder (USERPROFILE, LOCALAPPDATA, APPDATA) as a Linux path.
# Cached in rig's state (they don't change, and every lookup starts cmd.exe;
# a cache in a variable would be lost in the $(...) every caller uses).
win_env() { # NAME
  local cache="$RIG_STATE/windows.env" v
  v=$(awk -F= -v k="$1" '$1==k {sub(/^[^=]*=/,""); print; exit}' "$cache" 2>/dev/null)
  if [[ -z $v ]]; then
    v=$(win_cmd "echo %$1%")
    [[ -n $v && $v != "%$1%" ]] || return 1
    v=$(wslpath -u "$v")
    mkdir -p "$RIG_STATE" && printf '%s=%s\n' "$1" "$v" >>"$cache"
  fi
  printf '%s' "$v"
}
win_path() { wslpath -w "$1"; }   # Linux path on the Windows drive -> C:\...

# Start a Windows program in the background (the tray apps: GlazeWM, PowerToys).
win_start() { # Linux path to the .exe
  win_cmd "start \"\" \"$(win_path "$1")\"" >/dev/null || true
}

# UUIDv5 as Windows Terminal makes them: the name hashed as UTF-16LE.
uuid5() { # namespace name -> {guid}
  local ns=${1//[\{\}-]/} h
  h=$( { printf "$(printf '%s' "$ns" | sed 's/../\\x&/g')"; printf '%s' "$2" | iconv -f UTF-8 -t UTF-16LE; } | sha1sum | cut -c1-32)
  printf '{%s-%s-5%s-%x%s-%s}\n' "${h:0:8}" "${h:8:4}" "${h:13:3}" $(( (0x${h:16:1} & 0x3) | 0x8 )) "${h:17:3}" "${h:20:12}"
}

# ------------------------------------------------------------- files ----------
# Put a file in place on the Windows side; the original is backed up the
# first time. Returns 1 when it was already the same.
win_file_write() { # dest source
  local dest=$1 src=$2
  if [[ -f $dest ]] && cmp -s "$src" "$dest"; then return 1; fi
  if ! ledger_has win-file "$dest"; then
    if [[ -e $dest ]]; then
      local b; b="$RIG_STATE/win-backup/$(printf '%s' "$dest" | sha1sum | cut -c1-16)"
      mkdir -p "$(dirname "$b")" && cp "$dest" "$b"
      ledger_record win-file "$dest" "$b"
    else
      ledger_record win-file "$dest" none
    fi
  fi
  mkdir -p "$(dirname "$dest")" && cp "$src" "$dest"
}
win_file_restore() { # dest
  local prev; prev=$(ledger_last win-file "$1")
  [[ -n $prev ]] || return 0
  revert_win_file "$1" "$prev"
  ledger_forget win-file "$1"
}
revert_win_file() { # dest backup|none
  if [[ $2 == none ]]; then rm -f "$1"; prune_empty "$(dirname "$1")"
  elif [[ -f $2 ]]; then cp "$2" "$1"; fi
}

# ------------------------------------------------------------- registry -------
# Per-user values only (HKCU): no admin.
win_reg_get() { # key name -> "TYPE|data" (nothing if unset)
  win_reg query "$1" /v "$2" 2>/dev/null | awk -v n="$2" '
    { line = $0; sub(/^[ \t]+/, "", line) }
    index(line, n) == 1 { rest = substr(line, length(n) + 1); sub(/^[ \t]+/, "", rest)
      t = rest; sub(/[ \t].*/, "", t); d = rest; sub(/^[^ \t]+[ \t]+/, "", d); if (d == rest) d = ""
      print t "|" d; exit }'
}
win_reg_set() { # key name type data
  local cur; cur=$(win_reg_get "$1" "$2")
  [[ $cur == "$3|$4" ]] && return 0
  if ! ledger_has win-reg "$1|$2"; then ledger_record win-reg "$1|$2" "${cur:-none}"; fi
  win_reg add "$1" /v "$2" /t "$3" /d "$4" /f >/dev/null
}
win_reg_restore() { # key name
  local prev; prev=$(ledger_last win-reg "$1|$2")
  [[ -n $prev ]] || return 0
  revert_win_reg "$1|$2" "$prev"
  ledger_forget win-reg "$1|$2"
}
revert_win_reg() { # key|name TYPE|data|none
  local key=${1%|*} name=${1##*|}
  if [[ $2 == none ]]; then win_reg delete "$key" /v "$name" /f >/dev/null 2>&1 || true
  else win_reg add "$key" /v "$name" /t "${2%%|*}" /d "${2#*|}" /f >/dev/null 2>&1 || true; fi
}
