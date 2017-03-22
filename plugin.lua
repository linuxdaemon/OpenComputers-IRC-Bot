local class = require("class")

local PluginManager = class()

function PluginManager:_init(bot)
  self.bot = bot
  self.plugins = {}
  self.hooks = {}
end

function PluginManager:load_plugin(path)
end

function PluginManager:unload_plugin(path)
end
