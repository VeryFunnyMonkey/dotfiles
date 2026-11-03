-- Headless setup and updates, used by chezmoi's setup script and `rig update`:
--   nvim --headless "+lua require('config.bootstrap').run()" +qa
--   nvim --headless "+lua require('config.bootstrap').update()" +qa
-- Plugins themselves are installed by vim.pack when config.pack loads.
local M = {}

local function log(msg) io.stdout:write(msg .. "\n") end

local function wait_mason(names, timeout)
  local reg = require("mason-registry")
  local refreshed = false
  reg.refresh(function() refreshed = true end)
  vim.wait(120000, function() return refreshed end, 200)

  local pending = {}
  for _, name in ipairs(names) do
    local ok, pkg = pcall(reg.get_package, name)
    if not ok then
      log("mason: unknown package " .. name)
    elseif not pkg:is_installed() then
      -- lsp.lua may already have started it in the background
      if not pkg:is_installing() then
        log("mason: installing " .. name)
        pkg:install()
      end
      pending[name] = pkg
    end
  end
  -- Done when each is installed. A package that sits idle (not installing,
  -- not installed) for 10s has failed.
  local idle = {}
  vim.wait(timeout or 900000, function()
    for name, pkg in pairs(pending) do
      if pkg:is_installing() then
        idle[name] = nil
      elseif pkg:is_installed() then
        pending[name] = nil
      else
        idle[name] = (idle[name] or 0) + 1
        if idle[name] > 20 then pending[name] = nil end
      end
    end
    return next(pending) == nil
  end, 500)
  local failed = 0
  for _, name in ipairs(names) do
    local ok, pkg = pcall(reg.get_package, name)
    if ok and not pkg:is_installed() then
      log("mason: FAILED " .. name)
      failed = failed + 1
    end
  end
  return failed
end

-- Plugins on disk that the config no longer lists (vim.pack keeps them).
local function remove_unused_plugins()
  local unused = {}
  for _, p in ipairs(vim.pack.get(nil, { info = false })) do
    if not p.active then table.insert(unused, p.spec.name) end
  end
  if #unused > 0 then
    log("plugins: removing unused " .. table.concat(unused, ", "))
    vim.pack.del(unused)
  end
end

function M.run()
  remove_unused_plugins()
  -- Plugins already on disk keep whatever revision they had; move them to the
  -- committed lockfile so every machine runs the same versions.
  log("plugins: syncing to nvim-pack-lock.json")
  vim.pack.update(nil, { target = "lockfile", force = true })
  local mods = require("config.modules")
  log("treesitter: installing parsers")
  require("nvim-treesitter").install(mods.parsers):wait(600000)
  if wait_mason(mods.mason) > 0 then
    log("nvim bootstrap: some tools failed to install (see above)")
    vim.cmd("cquit 1")
  end
  log("nvim bootstrap done")
end

function M.update()
  remove_unused_plugins()
  log("plugins: updating")
  vim.pack.update(nil, { force = true })
  local mods = require("config.modules")
  require("nvim-treesitter").update():wait(600000)

  -- Mason: reinstall anything with a newer version
  local reg = require("mason-registry")
  local refreshed = false
  reg.refresh(function() refreshed = true end)
  vim.wait(120000, function() return refreshed end, 200)
  local upgrading = {}
  for _, pkg in ipairs(reg.get_installed_packages()) do
    local ok, latest = pcall(function() return pkg:get_latest_version() end)
    local cur_ok, cur = pcall(function() return pkg:get_installed_version() end)
    if ok and cur_ok and latest and cur and latest ~= cur then
      log(("mason: %s %s -> %s"):format(pkg.name, cur, latest))
      if not pkg:is_installing() then pkg:install() end
      table.insert(upgrading, pkg)
    end
  end
  vim.wait(900000, function()
    for _, pkg in ipairs(upgrading) do
      if pkg:is_installing() then return false end
    end
    return true
  end, 500)
  if wait_mason(mods.mason) > 0 then vim.cmd("cquit 1") end
  log("nvim update done")
end

return M
