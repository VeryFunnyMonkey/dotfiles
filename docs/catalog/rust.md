# lang-rust (off by default)

Rust: **rust-analyzer** (checks with clippy) and rustfmt on save. The **rust** runtime is **rustup** (never the distro's rust): stable toolchain plus rustfmt, clippy and rust-analyzer, under `~/.local/share/{rustup,cargo}`. `rig update` runs `rustup update`.

`rig module enable lang-rust` when you start a Rust project. `rig module disable --purge lang-rust` also deletes the toolchain.
