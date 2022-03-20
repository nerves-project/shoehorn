import Config

config :shoehorn,
  init: [:system_init],
  handler: MyProject.RestartHandler
