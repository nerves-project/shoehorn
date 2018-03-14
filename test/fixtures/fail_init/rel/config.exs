# Import all plugins from `rel/plugins`
# They can then be used by adding `plugin MyPlugin` to
# either an environment, or release definition, where
# `MyPlugin` is the name of the plugin module.
Path.join(["rel", "plugins", "*.exs"])
|> Path.wildcard()
|> Enum.map(&Code.eval_file(&1))

use Mix.Releases.Config,
  # This sets the default release built by `mix release`
  default_release: :default,
  # This sets the default environment used by `mix release`
  default_environment: :dev

# For a full list of config options for both releases
# and environments, visit https://hexdocs.pm/distillery/configuration.html

# You may define one or more environments in this file,
# an environment's settings will override those of a release
# when building in that environment, this combination of release
# and environment configuration is called a profile

environment :dev do
  set(dev_mode: true)
  set(include_erts: false)
  set(cookie: :"2e8$[zB|Ogn<wS6I;{QT~f1FqOW=Qx/<Un21;&0zlXJHQw!O}6yg`9hbRX[Y,Bs=")
end

environment :prod do
  set(include_erts: true)
  set(include_src: false)
  set(cookie: :"~,pt|vEb1c~WuiMKOOB36w%RgD,,tk%B74mJ]nC4%=oum|<Z?mr$3Bi;Yl(^8$t|")
end

# You may define one or more releases in this file.
# If you have not set a default release, or selected one
# when running `mix release`, the first release in the file
# will be used by default

release :fail_init do
  set(version: current_version(:fail_init))
  plugin(Shoehorn.Plugin)
end
