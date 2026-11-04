# needs: fuse server
# srv: mount a server (the srvbox container, sshd) over SSH with rclone + FUSE.
install_rig --profile minimal --yes
check "install ok (rclone + fuse3 in core)" 'command -v rclone >/dev/null && command -v fusermount3 >/dev/null'
srv add srvbox debian@srvbox "~" > /tmp/add.log 2>&1
check "srv add + ssh test" 'grep -q "ssh login works" /tmp/add.log'
srv mount srvbox > /tmp/mount.log 2>&1
check "srv mount" '[[ $? -eq 0 ]] && grep -q " $HOME/Servers/srvbox fuse" /proc/mounts' || tail -n 20 ~/.local/state/srv/srvbox.log
cat /tmp/mount.log
echo "hello from this machine" > ~/Servers/srvbox/from-local.txt
sleep 2
check "local write reaches the server" '[[ $(srv ssh srvbox -- cat from-local.txt) == "hello from this machine" ]]'
srv ssh srvbox -- 'echo "hello from the server" > from-server.txt'
sleep 7
check "server write shows in the mount" '[[ $(cat ~/Servers/srvbox/from-server.txt 2>/dev/null) == "hello from the server" ]]'
check "status for tmux" '[[ $(srv _status --tmux) == *"srvbox"* ]]'
check "prompt segment" 'zsh -ic "_srv_prompt; print -r -- \$SRV_SEG" 2>/dev/null | grep -q srvbox'
check "srv ls marks it mounted" 'srv ls | grep -q "● srvbox"'
DEV_NO_ATTACH=1 srv dev srvbox >/dev/null 2>&1; sleep 2
check "srv dev: workspace in the mount" '[[ $(tmux display -p -t srvbox:code.1 "#{pane_current_path}") == "$HOME/Servers/srvbox" ]]'
sleep 1
check "tmux shows the mount (srv pushes it; nothing polls)" '[[ $(tmux show -gv @srv 2>/dev/null) == *srvbox* ]]'
tmux kill-server 2>/dev/null
srv umount srvbox > /tmp/um.log 2>&1
check "srv umount" '! grep -q " $HOME/Servers/srvbox fuse" /proc/mounts && [[ -z $(srv _status) ]] && [[ ! -d ~/Servers/srvbox ]]'
srv mount srvbox >/dev/null 2>&1
pkill -9 -f "rclone mount" ; sleep 1
check "doctor spots a stale mount" '! srv doctor > /tmp/doc.log 2>&1; grep -q "stale mount" /tmp/doc.log'
srv umount --force srvbox > /tmp/force.log 2>&1
check "umount --force clears it" '! grep -q " $HOME/Servers/srvbox fuse" /proc/mounts'
srv mount srvbox >/dev/null 2>&1
~/.local/bin/rig uninstall --everything --yes > /tmp/un.log 2>&1
check "rig uninstall unmounts and removes srv data" '! grep -q " $HOME/Servers/srvbox fuse" /proc/mounts && [[ ! -d ~/.config/srv ]]'
done_tests
