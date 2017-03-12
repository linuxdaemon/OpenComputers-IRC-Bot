local serialization = require("serialization")

local manager = {}

function manager:new(bot)
  o = {
    bot=bot
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

function manager:load(perms)
  self.users = {}
  self.groups = {}
  for group,tbl in pairs(perms) do
    self.groups[group:lower()] = tbl
    for _,user in ipairs(tbl.users) do
      user = user:gsub("*", ".*")
      if not self.users[user:lower()] then
        self.users[user:lower()] = {}
      end
      for _,perm in ipairs(tbl.perms) do
        self.users[user:lower()][perm:lower()] = true
      end
    end
  end
end

function manager:user_has_perm(user, perm)
  assert(self.users ~= nil)
  for u,perms in pairs(self.users) do
    if user:match(u) then
      if perms[perm] then
        return true
      end
    end
  end
  return false
end

return manager