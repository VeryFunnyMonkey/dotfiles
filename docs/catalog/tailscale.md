# tailscale

Installs **Tailscale** and logs this machine in to your tailnet.

- **Servers into srv:** not part of this item: the first setup on any machine offers to import your servers into srv (see the README), and `srv import <file>` works any time.

- Linux: `tailscaled` is enabled, and setup runs `sudo tailscale up` when the machine is logged out (follow the link). Already logged in: nothing changes.
- macOS: the Tailscale app. rig installs it with Homebrew unless it's already in Applications (the App Store version counts, and is left alone on uninstall); open it once and log in.
- `rig doctor` shows whether it's connected. Uninstalling rig never logs you out.
