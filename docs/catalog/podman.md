# podman: containers, rootless and Docker-compatible

Podman runs the same images as Docker without a background daemon, and **rootless**: containers run as you, so there's no `docker` group (which is effectively root) and an agent running code in a container can't use it to take over the machine.

It's set up to look like Docker:

- `docker ...` runs Podman (the `podman-docker` shim on Linux; an alias on macOS).
- `docker compose` / `podman compose` run your compose files.
- `DOCKER_HOST` points at Podman's Docker-compatible socket, so lazydocker, agent tooling and libraries that talk to "Docker" find it.

| | How |
|---|---|
| Linux, WSL | runs natively; rig adds the sub-ID ranges rootless needs if your user lacks them, and enables the per-user `podman.socket` |
| macOS | a small Linux VM (`podman machine`) created on first setup and started; `podman machine stop`/`start` when you like. Deselecting stops it and asks before deleting it (your images and volumes live in it) |

Building for the servers: `podman build --platform linux/arm64 ...` (the Oracle Cloud hosts are arm64) and push as usual.

Differences from Docker you may meet: ports below 1024 need a sysctl when rootless; files written into bind mounts can show odd ownership (user-ID mapping; `--userns=keep-id` helps); unqualified image names may need `docker.io/`. **The servers stay on Docker** (Pterodactyl Wings, Nextcloud AIO, Portainer and the Traefik/cAdvisor socket integrations need it).
