# tailscale

Installs **Tailscale** and logs this machine in to your tailnet.

- **Servers into srv:** setup asks for a hosts file to copy into `srv`, so you can mount any of those servers at `~/Servers/<host>`. Either a simple list, one `name  user@host[:port]  [folder]` per line (see `extras/srv-hosts.example`), or an Ansible inventory (`hosts.yml`, or its folder). Skip it and run `srv import <file>` any time; `srv import` alone re-reads the last file, and it only replaces hosts it imported.

- Linux: `tailscaled` is enabled, and setup runs `sudo tailscale up` when the machine is logged out (follow the link). Already logged in: nothing changes.
- macOS: the Tailscale app (brew cask); open it once and log in.
- `rig doctor` shows whether it's connected. Uninstalling rig never logs you out.
