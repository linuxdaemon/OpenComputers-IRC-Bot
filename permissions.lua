local Manager = {}

Manager.__index = Manager

setmetatable(Manager, {
  __call = function(self, bot)
    return setmetatable({bot=bot}, self)
  end
})

function Manager:load(perms)
  self.users = {}
  self.groups = {}
  for group,tbl in pairs(perms) do
    self.groups[group:lower()] = tbl
    for _,mask in ipairs(tbl.users) do
      local mask = mask:gsub("*", ".*")
      if not self.users[mask:lower()] then
        self.users[mask:lower()] = {}
      end
      for _,perm in ipairs(tbl.perms) do
        self.users[mask:lower()][perm:lower()] = true
      end
    end
  end
  return true
end

function Manager:user_has_perm(user, perm)
  assert(self.users ~= nil)
  for mask,perms in pairs(self.users) do
    if user:match(mask) and perms[perm] then
      return true
    end
  end
  return false
end

return manager
