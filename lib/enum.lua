local enum = {}

function enum.unique(...)
  local args = table.pack(...)
  local t = {}
  for k,v in ipairs(args) do
    t[v] = k
  end
  return t
end
