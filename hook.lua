local enum = require("enum")

local hook = {}

hook.type = enum(
  "COMMAND",
  "RAW"
)

function hook.command(func, aliases, perms)
  local aliases = type(aliases) == "string" and {aliases} or aliases
  return {type=hook.type.COMMAND, func=func, aliases=aliases, perms=perms}
end

function hook.raw(func, cmd)
  local cmd = cmd and tostring(cmd) or "*"
  return {type=hook.type.RAW, func=func, cmd=cmd}
end

return hook
