local hook_base = {}

local hook = {}

function hook.command(func, trigger, perms)
  return {type="command", func=func, trigger=trigger, perms=perms}
end

return hook