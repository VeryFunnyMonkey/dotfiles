# ops

For infrastructure work (the Ansible repo, Compose stacks, OpenTofu):

| Files | Support |
|---|---|
| Ansible (`playbooks/`, `roles/*/tasks/` etc., `inventory/`, `group_vars/`, `host_vars/`) | ansible-language-server: module/option completion and docs, ansible-lint warnings |
| YAML | yaml-language-server with schemastore.org schemas (docker-compose, GitHub Actions, ...) |
| `compose.yml`, `docker-compose*.yml` | docker-compose-language-service |
| `Dockerfile` | dockerfile-language-server |
| `.tf`, `.tofu`, `.tfvars` | tofu-ls; `tofu fmt` on save |
| shell scripts | bash-language-server with shellcheck; shfmt on save |

YAML is formatted on demand only (`<leader>cf`), never on save, so existing repos don't get reformatted. Installs **opentofu** (for `tofu fmt`) and needs the **node** runtime.
