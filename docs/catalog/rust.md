# rust

Rust: **rust-analyzer** (checks with clippy) and rustfmt on save. The **rust** runtime is **rustup** (never the distro's rust): stable toolchain plus rustfmt, clippy and rust-analyzer, under `~/.local/share/{rustup,cargo}`. `rig update` runs `rustup update`.

`rig add rust` when you start a Rust project. `rig remove rust` offers to delete the toolchain too.
