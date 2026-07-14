local config = {
  enabled = true,
  logLevel = 2,
}

local configDesc = {
  enabled = "Whether the mod is enabled or not.",
  logLevel =
  "What kinds of logs should be printed to the console. Set a higher level to see more detailed logs. Set to one of: 0 = Off/No logs, 1 = Errors, 2 = Warnings, 3 = Info, 4 = Debug",
}

return config, configDesc
