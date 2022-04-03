import Config

config :shoehorn,
  init: [:system_init],
  app: :my_project,
  handler: MyProject.RestartHandler
