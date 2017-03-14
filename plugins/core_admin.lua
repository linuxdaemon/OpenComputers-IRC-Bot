local hook = dofile("hook.lua")

local function stop(event)
  event.bot:close()
end

local function reconnect(event)
  event.bot:connect()
end

local hooks = {
  hook.command(stop, "stop", {"botcontrol"}),
  hook.command(reconnect, "reconnect", {"botcontrol"}),
}

return hooks
