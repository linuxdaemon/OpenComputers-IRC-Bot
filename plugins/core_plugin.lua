local hook = dofile("hook.lua")
local fs = require("filesystem")
local shell = require("shell")

local function update_plugins(event)
  local plugin_dir = fs.concat(shell.getWorkingDirectory(), "plugins")
  local update_fs = "/mnt/ircbot"
  local update_dir = fs.concat(update_fs, "plugins")
  if not fs.exists(update_fs) then
    return "Update floppy not mounted"
  end
  for file in fs.list(update_dir) do
    fs.copy(fs.concat(update_dir, file), fs.concat(plugin_dir, file))
    if not event.bot:plugin_load(fs.concat(plugin_dir, file)) then
      return "Plugin '"..file.."' failed to update"
    end
  end
  return "Plugins updated."
end

local function reload_plugin(event)
  local plugin_dir = fs.concat(shell.getWorkingDirectory(), "plugins")
  local path = fs.concat(plugin_dir, event.text)
  if event.bot:plugin_load(path) then
    return "Plugin reloaded."
  else
    return "Plugin reload failed"
  end
end

local function reload_all(event)
  return "Not implemented"
end

local hooks = {
  hook.command(update_plugins, "updateplugins", {"botcontrol"}),
  hook.command(reload_plugin, "reloadplugin", {"botcontrol"}),
  hook.command(reload_all, "reloadall", {"botcontrol"})
}

return hooks