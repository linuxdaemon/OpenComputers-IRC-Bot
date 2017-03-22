local function class()
  local c = {}
  c.__index = c
  local mt = {}
  mt.__call = function(self, ...)
    local obj = {}
    setmetatable(obj, c)
    if self._init then self._init(obj, ...) end
    return obj
  end
  return setmetatable(c, mt)
end

return class
