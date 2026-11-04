# Languages and agents: servers attach for Python, TS, Ansible, Compose,
# OpenTofu, shell, Go, Rust; add/remove items; agents install and uninstall.
lsp() { (cd "$(dirname "$1")" && eval "$(fnm env --shell bash 2>/dev/null)"; nvim --headless -c "luafile $HOME/dotfiles/tests/lspcheck.lua" "$1" 2>/dev/null | tail -n1); }
pkgs | sort > /tmp/pkgs-before.txt

install_rig --profile minimal --select python,web,ops,tailscale,claude,opencode --yes
check "install ok" '[[ $? -eq 0 ]]'
check "item packages installed (uv, opentofu, tailscale, fnm)" 'pacman -Q uv opentofu tailscale fnm >/dev/null'
check "node via fnm" 'eval "$(fnm env --shell bash)"; node --version | grep -q ^v'
check "mason has the ops/python/web tools" 'for t in pyright ruff typescript-language-server ansible-language-server yaml-language-server tofu-ls bash-language-server shfmt prettierd; do [[ -e ~/.local/share/nvim/mason/bin/$t ]] || { echo "  missing $t"; exit 1; }; done'
check "agents installed (claude, opencode)" 'command -v claude >/dev/null && command -v opencode >/dev/null'
check "dev defaults to claude" '[[ $(dev agent) == claude ]]'
check "tailscale step ran (no systemd in a container)" 'grep -q "tailscale" /tmp/install.log'

mkdir -p ~/w/ans/playbooks ~/w/ans/roles/r/tasks ~/w/py ~/w/web ~/w/tf ~/w/sh
touch ~/w/ans/ansible.cfg
printf -- '- hosts: all\n  tasks:\n    - name: ping\n      ansible.builtin.ping:\n' > ~/w/ans/playbooks/site.yml
printf 'services:\n  web:\n    image: nginx\n' > ~/w/ans/compose.yml
printf 'import os\nprint(os.getcwd())\n' > ~/w/py/main.py
printf '{"compilerOptions":{}}' > ~/w/web/tsconfig.json; printf 'const x: number = 1\n' > ~/w/web/index.ts
printf 'variable "x" {\n  type = string\n}\n' > ~/w/tf/main.tf
printf '#!/bin/bash\necho hi\n' > ~/w/sh/s.sh
for d in ans py web tf sh; do git -C ~/w/$d init -q 2>/dev/null; done
r=$(lsp ~/w/ans/playbooks/site.yml); echo "  $r"; check "ansible playbook -> ansiblels" '[[ $r == *"ft=yaml.ansible"* && $r == *ansiblels* ]]'
r=$(lsp ~/w/ans/compose.yml); echo "  $r"; check "compose -> docker_compose_language_service" '[[ $r == *docker_compose_language_service* ]]'
r=$(lsp ~/w/py/main.py); echo "  $r"; check "python -> pyright + ruff" '[[ $r == *pyright* && $r == *ruff* ]]'
r=$(lsp ~/w/web/index.ts); echo "  $r"; check "typescript -> ts_ls" '[[ $r == *ts_ls* ]]'
r=$(lsp ~/w/tf/main.tf); echo "  $r"; check ".tf -> terraform + tofu_ls" '[[ $r == *"ft=terraform"* && $r == *tofu_ls* ]]'
r=$(lsp ~/w/sh/s.sh); echo "  $r"; check "shell -> bashls" '[[ $r == *bashls* ]]'
printf 'if true;then\necho   hi\nfi\n' > ~/w/sh/f.sh
(eval "$(fnm env --shell bash)"; nvim --headless ~/w/sh/f.sh -c 'lua vim.defer_fn(function() vim.cmd("write") vim.cmd("qa!") end, 4000)' >/dev/null 2>&1)
check "shfmt formats on save" 'grep -q "^if true; then" ~/w/sh/f.sh'

RIG_YES=1 rig add go > /tmp/go.log 2>&1
check "lang-go: go installed" 'command -v go >/dev/null'
mkdir -p ~/w/go && printf 'module x\n\ngo 1.22\n' > ~/w/go/go.mod && printf 'package main\n\nfunc main() {}\n' > ~/w/go/main.go
r=$(WAIT=20000 lsp ~/w/go/main.go); echo "  $r"; check "go -> gopls" '[[ $r == *gopls* ]]'

RIG_YES=1 rig add rust > /tmp/rust.log 2>&1
check "lang-rust: rustup stable + rust-analyzer" 'RUSTUP_HOME=~/.local/share/rustup rustup component list --installed 2>/dev/null | grep -q rust-analyzer'
export RUSTUP_HOME=~/.local/share/rustup CARGO_HOME=~/.local/share/cargo
(cd ~/w && cargo new -q rs >/dev/null 2>&1)
r=$(WAIT=25000 lsp ~/w/rs/src/main.rs); echo "  $r"; check "rust -> rust_analyzer" '[[ $r == *rust_analyzer* ]]'
RIG_YES=1 rig remove rust > /tmp/rustoff.log 2>&1
check "disable --purge removes the toolchain" '[[ ! -d ~/.local/share/rustup && ! -d ~/.local/share/cargo ]]'
check "rust gone from nvim" '! grep -q rust_analyzer ~/.config/nvim/lua/config/modules.lua'
doc=$(rig doctor 2>&1); check "doctor lists the selection" '[[ $doc == *"selected:"*go* ]]'

RIG_YES=1 rig remove opencode > /tmp/ag.log 2>&1
check "agents remove uninstalls opencode" '! command -v opencode >/dev/null'
RIG_YES=1 rig add codex > /tmp/ag2.log 2>&1
check "agents add codex (npm)" 'eval "$(fnm env --shell bash)"; command -v codex >/dev/null'
doc=$(rig doctor 2>&1); check "doctor lists agents" '[[ $doc == *"OpenAI Codex CLI"* ]]'

~/.local/bin/rig uninstall --everything --yes > /tmp/un.log 2>&1
check "uninstall ok" '[[ $? -eq 0 ]]'
pkgs | sort > /tmp/pkgs-after.txt
check "packages back to before" '[[ "$(cat /tmp/pkgs-before.txt)" == "$(cat /tmp/pkgs-after.txt)" ]]'
check "fnm data (rig-created) removed" '[[ ! -d ~/.local/share/fnm ]]'
check "agents removed" '! command -v claude >/dev/null && [[ ! -e ~/.local/bin/claude ]]'
done_tests
