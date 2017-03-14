local component = require("component")

local hook = dofile("hook.lua")

local debug = component.debug

local zwsp_hex = {"E2", "80", "8B"}
local zwsp_dec = {}
for k,v in ipairs(zwsp_hex) do
  zwsp_dec[k] = tonumber(v, 16)
end

local zwsp_char = string.char(table.unpack(zwsp_dec))

local function players(ev)
  local player_list = debug.getPlayers()
  if #player_list == 0 then
    return "No players online."
  else
    for k,v in ipairs(player_list) do
      player_list[k] = v:sub(1,1) .. zwsp_char .. v:sub(2)
    end
    return "Players: " .. table.concat(player_list, ", ")
  end
end

local function server_say(ev)
  local text = ev.text
  local res = debug.runCommand("say Test123")
  return tostring(res)
end

local hooks = {
  hook.command(players, "players"),
  hook.command(server_say, "ssay", {"botcontrol"})
}

return hooks
