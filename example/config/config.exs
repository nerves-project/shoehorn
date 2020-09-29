import Config

config :shoehorn,
  init: [{IO, :puts, ["init_1"]}, {IO, :puts, ["init_2"]}],
  app: :example,
  handler: Example.RestartHandler
