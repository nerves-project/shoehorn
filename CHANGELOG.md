# Changelog

## v0.1.2
* Bug Fixes
  * Only look in `:code.lib_dir()` for the Application lib dir instead of involving `mix`
* Enhancements
  * Warn when an app listed in `:init` or `:app` does not exist.
  * Output message about booting using bootloader during `mix release`

## v0.1.1
* Bug Fixes
  * Fixed issue with release path being constructed incorrectly.

## v0.1.0

Initial release to hex.
