# Changelog

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
