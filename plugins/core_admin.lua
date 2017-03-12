local hook = dofile("hook.lua")

local function stop(event)
  event.bot.stop()
end

local hooks = {
  hook.command(stop, "stop", {"botcontrol"})
}

return hooks