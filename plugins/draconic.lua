local component = require("component")

local hook = dofile("hook.lua")

local draconic_pwr = component.draconic_rf_storage

local function round(num, digits)
  local mult = 10^(digits or 0)
  return math.floor(num * mult + 0.5) / mult
end

local function delta_ticks_to_ts(dt)
  local ts = ""
  local tps = 20
  local tpm = tps * 60
  local tph = tpm * 60
  local tpd = tph * 24
  local tpy = tpd * 365

  local y = math.floor(dt / tpy)
  dt = math.fmod(dt, tpy)

  local d = math.floor(dt / tpd)
  dt = math.fmod(dt, tpd)

  local h = math.floor(dt / tph)
  dt = math.fmod(dt, tph)

  local m = math.floor(dt / tpm)
  dt = math.fmod(dt, tpm)

  local s = math.floor(dt / tps)
  dt = math.fmod(dt, tps)

  local t = math.floor(dt)

  if y > 0 then
    ts = ts .. tostring(y) .. "y"
  end

  if d > 0 then
    ts = ts .. tostring(d) .. "d"
  end

  if h > 0 then
    ts = ts .. tostring(h) .. "h"
  end

  if m > 0 then
    ts = ts .. tostring(m) .. "m"
  end

  if s > 0 then
    ts = ts .. tostring(s) .. "s"
  end

  if t > 0 then
    ts = ts .. tostring(t) .. "t"
  end

  return ts
end

local suffixes = {
  "",
  "K",
  "M",
  "B",
  "T",
  "Quad",
  "Quint"
}

local function format_num(n, d)
  local d = d or 4
  local i = 1
  while n > 1000 do
    n = n / 1000
    i = i + 1
  end
  return tostring(round(n, d) .. suffixes[i])
end

local function check_pwr()
  local stored = draconic_pwr.getEnergyStored()
  local max_pwr = draconic_pwr.getMaxEnergyStored()
  local xfr = draconic_pwr.getTransferPerTick()
  local fmt = "Power: %s/%s (%s%%) [Xfr: %s rf/t]"
  local msg = string.format(fmt, format_num(stored), format_num(max_pwr), format_num(round((stored / max_pwr) * 100, 3)), format_num(xfr))
  if xfr > 0 then
    local ttf_t = (max_pwr - stored) / xfr
    msg = msg .. " [Time to Full: " .. delta_ticks_to_ts(ttf_t) .. "]"
  elseif xfr < 0 then
    local tte_t = stored / -xfr
    msg = msg .. " [Time to Empty: " .. delta_ticks_to_ts(tte_t) .. "]"
  end
  return msg
end

local hooks = {
  hook.command(check_pwr, "power")
}

return hooks
