local hook = dofile("hook.lua")
local fs = require("filesystem")
local shell = require("shell")

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
  hook.command(reload_plugin, "reloadplugin", {"botcontrol"}),
  hook.command(reload_all, "reloadall", {"botcontrol"})
}

return hooks
