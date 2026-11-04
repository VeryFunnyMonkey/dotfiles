# tailscale

Installs **Tailscale** and logs this machine in to your tailnet.

- **Servers into srv:** setup offers to copy the hosts from your ansible inventory (`~/Projects/ansible` by default) into `srv`, so you can mount any of them at `~/Servers/<host>`. Run `srv import-homelab [path]` again any time; it only updates the hosts it imported.

- Linux: `tailscaled` is enabled, and setup runs `sudo tailscale up` when the machine is logged out (follow the link). Already logged in: nothing changes.
- macOS: the Tailscale app (brew cask); open it once and log in.
- `rig doctor` shows whether it's connected. Uninstalling rig never logs you out.
