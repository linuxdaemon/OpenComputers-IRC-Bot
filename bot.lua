local component = require("component")
local internet = require("internet")
local serialization = require("serialization")
local fs = require("filesystem")
local shell = require("shell")

local permissions = dofile("permissions.lua")

local plugin_dir = fs.concat(shell.getWorkingDirectory(), "plugins")

local bot = {
  hooks = {
    commands = {}
  },
  plugins = {},
  config = {},
  running = false
}

local function rsplit(text, char)
  for i=#text,1,-1 do
    if text:sub(i, i) == char then
      return {text:sub(1, i-1), text:sub(i+1)}
    end
  end
end

function bot:log(line)
  local res, err = pcall(function() print(line) end)
  if not res then
    io.stderr:write(err .. "\n" .. debug.traceback())
  end
  local f, err = io.open()
end

function bot:plugin_unload(path)
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

function bot:load_all_plugins()
  for file in fs.list(plugin_dir) do
    if file:sub(-4, -1) == ".lua" then
      self:plugin_load(fs.concat(plugin_dir, file))
    end
  end
end

function bot:plugin_load(path)
  local file_path = fs.canonical(path)
  local file_name = fs.name(file_path)
  local title = rsplit(file_name, ".")[1]
  if not fs.exists(file_path) then
    print("Path " .. file_path .. " is non-existant")
    return false
  end
  if self.plugins[file_name:lower()] then
    self:plugin_unload(file_path)
  end
  print("Loading plugin '"..title.."'")
  local f, err = loadfile(file_path)
  if not f then
    io.stderr:write("Plugin loading failed\n"..err.."\n"..debug.traceback().."\n")
    os.sleep(5)
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
      exit(1)
    end
  end
  return true
end

function bot:send(msg)
  print(">> " .. msg)
  self.sock:write(msg .. "\r\n")
end

function bot:msg(line, target)
  self:send("PRIVMSG " .. target .. " :" .. line)
end

function bot:notice(line, target)
  self:send("NOTICE " .. target .. " :" .. line)
end

local function parse(line)
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

local function pfxToNuh(pfx)
  local expos = pfx:find("!")
  local atpos = pfx:find("@", expos+1)
  local nick = pfx:sub(1,expos-1)
  local ident = pfx:sub(expos+1, atpos-1)
  local host = pfx:sub(atpos+1)
  return nick, ident, host
end

local function event(bot, nick, user, host, text, chan)
  return {
    bot = bot,
    nick = nick,
    user = user,
    host = host,
    text = text,
    chan = chan,
    reply = function(msg) bot:msg(msg, chan) end
  }
end

function bot:handle_command(cmd, parsed)
  if self.hooks.commands[cmd:lower()] then
    local hook = self.hooks.commands[cmd:lower()]
    local n, u, h = pfxToNuh(parsed.prefix:sub(2))
    local mask = parsed.prefix:sub(2)
    if hook.perms then
      local has_perm = false
      -- print(serialization.serialize(hook.perms))
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

function bot:connect()
  if self.sock then self.sock:close() end
  self.sock = internet.open(self.config.server.host, self.config.server.port)
  self:send("NICK " .. self.nick)
  self:send("USER " .. self.config.ident .. " 8 0 :" .. self.config.realname)
end

function bot:run()
  self.running = true
  self.config = dofile("config.lua")
  self.permissions_manager = permissions:new(bot)
  self.permissions_manager:load(self.config.permissions)
  self.nick = self.config.nick
  self:load_all_plugins()
  self:connect()
  self.connectTries = 0
  while self.running do
    if not self.sock then
      self:connect()
      self.connectTries = self.connectTries + 1
      if self.connectTries > 5 then
        print("Unable to connect")
        self:stop()
      end
    else
      local line = self.sock:read()
      if line == nil then
        if self.running then
          self:connect()
        else
          self:stop()
        end
      end
      print(line)
      local parsed = parse(line)
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
        if msg:sub(1,1) == config.cmd_prefix and #msg > 1 then
          local cmd = msg:sub(2)
          self:handle_command(cmd, parsed)
        end
      end
    end
  end
end

function bot:stop()
  print("Stopping bot...")
  self:send("QUIT")
  os.sleep(.1)
  self.sock:close()
  os.sleep(.1)
  os.exit()
end

bot:run()
