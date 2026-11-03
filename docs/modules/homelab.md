# homelab

**Tailscale**, so this machine joins the homelab tailnet. The servers are on it already; the tailnet policy stops servers reaching personal devices.

- Linux: `tailscaled` is enabled, and setup runs `sudo tailscale up` when the machine is logged out (follow the link). Already logged in: nothing changes.
- macOS: the Tailscale app (brew cask); open it once and log in.
- `rig doctor` shows whether it's connected. Uninstalling rig never logs you out.
