local plugin = {}

function plugin:new(file, name)
  o = {
    hooks={},
    file=file,
    name=name
  }
  setmetatable(o, self)
  self.__index = self
  return o
end



return plugin