# Changelog

## v0.3.0

The default strategy for how Shoehorn handles OTP application exits has changed.
Before this release, if an application were to exit the node would remain running
and that applications would remain stopped. This may be desireable for development
and test but is typically undesireable in production. This behaviour can be
customized by configuring the `handler` in the config. For example, in dev you can
use the module `Shoehorn.Handler.Ignore` to prevent the node from halting on failure. 

  ```elixir
  # config/dev.exs

  config :shoehorn,
    handler: Shoehorn.Handler.Ignore
  ```

Check out the [example application](https://github.com/nerves-project/shoehorn/tree/master/example) for information on implementing custom strategies.

## v0.2.0

  Renamed project Shoehorn.
  It became hard to discuss this project with the name Bootloader.

  * Enhancements
    * `:init` list can contain `:application`, `{m, f, a}`, or `{Module, [args]}`.

## v0.1.3

  * Bug Fixes
    * Add explicit functions for each of the Distillery Plugin behaviour callbacks.

## v0.1.2

  * Bug Fixes
    * Only look in `:code.lib_dir()` for the Application lib dir instead of involving `mix`
  * Enhancements
    * Warn when an app listed in `:init` or `:app` does not exist.
    * Output message about booting using shoehorn during `mix release`

## v0.1.1

  * Bug Fixes
    * Fixed issue with release path being constructed incorrectly.

## v0.1.0

  Initial release to hex.
