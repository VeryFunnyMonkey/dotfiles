-- Filetypes Neovim doesn't guess the way we want.
vim.filetype.add({
  extension = {
    tf = "terraform",       -- Neovim's default is TinyFugue
    tofu = "opentofu",
    tfvars = "terraform-vars",
  },
  filename = {
    ["compose.yml"] = "yaml.docker-compose",
    ["compose.yaml"] = "yaml.docker-compose",
    ["docker-compose.yml"] = "yaml.docker-compose",
    ["docker-compose.yaml"] = "yaml.docker-compose",
  },
  pattern = {
    -- Ansible: playbooks, roles, inventories and their vars
    [".*/playbooks/.*%.ya?ml"] = "yaml.ansible",
    [".*/roles/.*/tasks/.*%.ya?ml"] = "yaml.ansible",
    [".*/roles/.*/handlers/.*%.ya?ml"] = "yaml.ansible",
    [".*/roles/.*/defaults/.*%.ya?ml"] = "yaml.ansible",
    [".*/roles/.*/vars/.*%.ya?ml"] = "yaml.ansible",
    [".*/roles/.*/meta/.*%.ya?ml"] = "yaml.ansible",
    [".*/inventory/.*%.ya?ml"] = "yaml.ansible",
    [".*/group_vars/.*%.ya?ml"] = "yaml.ansible",
    [".*/host_vars/.*%.ya?ml"] = "yaml.ansible",
    [".*/docker%-compose%..*%.ya?ml"] = "yaml.docker-compose",
  },
})

-- Treesitter: these filetypes use existing parsers
vim.treesitter.language.register("yaml", { "yaml.ansible", "yaml.docker-compose" })
vim.treesitter.language.register("hcl", { "opentofu", "terraform-vars" })
