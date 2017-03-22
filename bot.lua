local component = require("component")
local internet = require("internet")
local serialization = require("serialization")
local fs = require("filesystem")
local shell = require("shell")

local Permissions = dofile("permissions.lua")

local working_dir = shell.getWorkingDirectory()
local plugin_dir = fs.concat(working_dir, "plugins")
local log_dir = fs.concat(working_dir, "logs")

local Bot = {
  running = false,
  hasQuit = false,
}

Bot.__index = Bot

setmetatable(Bot, {
    __call = function(self)
      return setmetatable({}, self)
    end
  })

local function rsplit(text, char)
  for i=#text,1,-1 do
    if text:sub(i, i) == char then
      return {text:sub(1, i-1), text:sub(i+1)}
    end
  end
end

local function pfxToNuh(pfx)
  local expos = pfx:find("!")
  local atpos = pfx:find("@", expos+1)
  local nick = pfx:sub(1,expos-1)
  local ident = pfx:sub(expos+1, atpos-1)
  local host = pfx:sub(atpos+1)
  return nick, ident, host
end

function Bot:log(line)
  local res, err = pcall(function() print(line) end)
  if not res then
    io.stderr:write(err .. "\n" .. debug.traceback() .. "\n")
  end
  local f, err = io.open(fs.concat(log_dir, "bot.log"), "a")
  if not f then
    io.stderr:write("Unable to open log file\n" .. err .. "\n" .. debug.traceback() .. "\n")
    self:close()
    os.exit(1)
  else
    f:write(line .. "\n")
    f:close()
  end
end

function Bot:plugin_unload(path)
  local file_name = fs.name(path)
  local title = rsplit(file_name, ".")[1]
  if not self.plugins[file_name:lower()] then -- Make sure the plugin is actually loaded
    return false
  end

  for _,hook in ipairs(self.plugins[file_name:lower()].hooks) do
    if hook.type == "command" then
      if self.hooks.commands[hook.trigger] and self.hooks.commands[hook.trigger].parent == title then
        self.hooks.commands[hook.trigger] = nil
      end
    end
  end
  return true
end

function Bot:load_all_plugins()
  for file in fs.list(plugin_dir) do
    if file:sub(-4, -1) == ".lua" then
      self:plugin_load(fs.concat(plugin_dir, file))
    end
  end
end

function Bot:plugin_load(path)
  local file_path = fs.canonical(path)
  local file_name = fs.name(file_path)
  local title = rsplit(file_name, ".")[1]
  if not fs.exists(file_path) then
    self:log("Path " .. file_path .. " is non-existant")
    return false
  end
  if self.plugins[file_name:lower()] then
    self:plugin_unload(file_path)
  end
  self:log("Loading plugin '"..title.."'")
  local f, err = loadfile(file_path)
  if not f then
    io.stderr:write("Plugin loading failed\n"..err.."\n"..debug.traceback().."\n")
    return false
  end

  local plugin_hooks = f()
  self.plugins[file_name:lower()] = {
    hooks = plugin_hooks,
    title = title:lower()
  }

  for _,hook in ipairs(plugin_hooks) do
    if hook.type == "command" then
      if self.hooks.commands[hook.trigger] == nil then
        self.hooks.commands[hook.trigger] = hook
        self.hooks.commands[hook.trigger].parent = title
      else
        io.stderr:write("Plugin loading failed, plugin '"..title.."' attempted to register hook '"..hook.trigger.."' which was already registered by '"..self.hooks.commands[hook.trigger].parent.."'\n")
        return false
      end
    else
      error("Invalid hook type: " .. hook.type)
      os.exit(1)
    end
  end
  return true
end

function Bot:send(msg)
  self:log(">> " .. msg)
  self.sock:write(msg .. "\r\n")
end

function Bot:msg(line, target)
  self:send("PRIVMSG " .. target .. " :" .. line)
end

function Bot:notice(line, target)
  self:send("NOTICE " .. target .. " :" .. line)
end

function Bot:parse(line)
  local pfx,cmd = "",""
  local words,params = {},{}
  for word in line:gmatch("[^ ]+") do
    words[#words + 1] = word
  end
  if words[1]:sub(1,1) == ":" then
    pfx = table.remove(words, 1)
  end
  cmd = table.remove(words, 1)
  while #words > 0 do
    if words[1]:sub(1,1) == ":" then
      params[#params + 1] = table.concat(words, " ")
      words = {}
    else
      params[#params + 1] = table.remove(words, 1)
    end
  end
  return {prefix=pfx, command=cmd, params=params}
end

local function event(bot, nick, user, host, text, chan)
  return {
    bot = bot,
    nick = nick,
    user = user,
    host = host,
    text = text,
    chan = chan,
    reply = function(msg) self:msg(msg, chan) end
  }
end

function Bot:handle_command(cmd, parsed)
  local hook = self.hooks.commands[cmd:lower()]
  if hook then
    local n, u, h = pfxToNuh(parsed.prefix:sub(2))
    local mask = parsed.prefix:sub(2)
    if hook.perms then
      local has_perm = false
      for _,perm in ipairs(hook.perms) do
        if self.permissions_manager:user_has_perm(mask, perm) then
          has_perm = true
          break
        end
      end
      if not has_perm then
        self:notice("Sorry, you don't have permission to do that", n)
        return
      end
    end
    local ev = event(self, n, u, h, parsed.params[#parsed.params]:sub(2), parsed.params[1])
    local result = self.hooks.commands[cmd:lower()].func(ev)
    if result then
      self:msg(result, parsed.params[1])
    end
  end
end

function Bot:connect()
  if self.hasQuit then
    return
  end
  self.connectTries = (self.connectTries or 0) + 1
  if self.connected then
    self:log("Reconnecting...")
    self.sock:close()
  else
    self.connected = true
    self:log("Connecting...")
  end
  self.sock = internet.open(self.config.server.host, self.config.server.port)
  self:send("NICK " .. self.nick)
  self:send("USER " .. self.config.ident .. " 8 0 :" .. self.config.realname)
end

function Bot:handle_line(line)
  self:log(line)

  local parsed = self:parse(line)
  if parsed.command == "PING" then
    self:send("PONG " .. parsed.params[#parsed.params])
  elseif parsed.command == "001" then
    self:send("JOIN :" .. table.concat(self.config.channels, ","))
  elseif parsed.command == "433" then
    self.nick = self.nick .. "_"
    self:send("NICK :" .. self.nick)
  elseif parsed.command == "PRIVMSG" then
    local chan = parsed.params[1]
    local msg = parsed.params[#parsed.params]
    if msg:sub(1,1) == ":" then
      msg = msg:sub(2)
    end
    if parsed.prefix == ":DC2Relay!thumpSrv@totallynotrobots/linuxdaemon/bot/testbot" and msg:sub(1,1) == "<" then
      local i = msg:find(">")
      msg = msg:sub(i + 2)
    end
    if msg:sub(1,1) == self.config.cmd_prefix and #msg > 1 then
      local cmd = msg:sub(2)
      self:handle_command(cmd, parsed)
    end
  end
end

function Bot:read_line()
  local line, err = self.sock:read()
  if not line then
    self:log("Read error: " .. tostring(err))
    repeat
      self:connect()
    until self.sock or self.connectTries > 5
    if self.connectTries > 5 then
      self:log("Unable to connect")
      self:stop()
      os.exit(1)
    end
  else
    self:handle_line(line)
  end
end

function Bot:run()
  if not fs.exists(log_dir) then
    fs.makeDirectory(log_dir)
  end

  self.running = true
  self.config = dofile("config.lua")
  self.permissions_manager = Permissions(self)
  self.permissions_manager:load(self.config.permissions)
  self.nick = self.config.nick
  self:load_all_plugins()
  self.connectTries = 0

  while self.running do
    if not self.hasQuit then
      self:connect()
      while self.connected do
        self:read_line()
      end
    else
      break
    end
  end
  self:close()
end

function Bot:close()
  self:log("Stopping bot...")
  if not self.hasQuit then
    self:quit()
  end
  if self.connected then
    self.sock:close()
    self.connected = false
  end
end

function Bot:quit(reason)
  if reason then
    self:send("QUIT :" .. reason)
  else
    self:send("QUIT")
  end
  self.hasQuit = true
end

local function main()
  local bot = Bot()
  bot:run()
end

main()
