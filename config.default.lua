return {
  nick = "OCBot",
  ident = "bot",
  realname = "OpenComputers",
  server = {
    host = "irc.esper.net",
    port = 6667
  },
  cmd_prefix = ">",
  channels = {"#oc"},
  plugin_bl = {},
  plugin_wl = {},
  permissions = {
    admin = {
      users = {
        "usera!a@irc.example.com",
        "*!userb@irc2.example.org"
      },
      perms = {
        "botcontrol"
      }
    }
  }
}
