# Changelog

## v0.9.2 - 2024-03-04

* Updates
  * Improve error message when an OTP application isn't found when building the
    OTP release script. It's usually due to a dependency typo or wrong targets
    spec, so point to that.

## v0.9.1 - 2022-04-04

* Updates
  * Improve detection of invalid applications being passed in the `:init` and
    `:last` options.
  * Fall back to a reasonable default when trying to get application modes from
    the release options. This fixes an exception when building the release.
  * Support release configuration via the release options in a project's
    `mix.exs`. Add a `:shoehorn` key to the release parameters to set `:init`,
    `:last` or the `:exxtra_dependencies` options.

## v0.9.0 - 2022-04-03

This is a major update to Shoehorn that includes **breaking changes**:

* The `:init` configuration option only supports applications now. MFAs are no
  longer supported and moved to `runtime.exs` or an `Application.start`
  callback.
* References to `use Shoehorn.Handler` need to be updated to `@behaviour
  Shoehorn.Handler`. This may require implementing additional functions.
* Elixir 1.9 is no longer supported. Please update to Elixir 1.10 or later.

The main update to Shoehorn is to move all application startup to the boot
script. This noticeably improves boot time on many Nerves platforms due to boot
scripts being able to load files without traversing the entire Erlang module
path list. These traversals are amazingly slow (sometimes seconds) due to a
combination of SquashFS slowness in this area and slow overall IO.

Using boot scripts to load all applications has some important improvements in
addition to performance:

* Application start order is deterministic and computed at compile-time. If you
  want to see the order, take a look at the end of the `shoehorn.script` in your
  release directory.
* Shoehorn alphabetizes the start of applications that could be ordered
  arbitrarily. This minimizes changes in start ordering when dependencies are
  added or removed.
* It enables experimental features like providing additional dependencies (using
  the `:extra_dependencies` configuration key) or hinting that dependencies get
  started as late as possible (the `:last` configuration key)
* You can remove the `:app` configuration key from your Shoehorn configuration.
  It's no longer needed.

Aside from the change from a macro to a behaviour and possibly needing to
implement callback functions, `Shoehorn.Handler` implementations work the same
as before.

## v0.8.0 - 2021-10-31

Shoehorn v0.8.0 completely removes support for Distillery.

## v0.7.0

Shoehorn 0.7.0 removes support for creating boot scripts using Distillery and
only supports using Elixir releases. As a result, the minimum supported version
of Elixir is now version 1.9.

## v0.6.0

* Enhancements
  * Added support for Elixir 1.9+ releases.
  * Distillery is now an optional dependency and ~> 2.1.
  * Updated supervisor specs and cleaned up warnings.

## v0.5.0

* Enhancements
  * Exclude distillery, artificery, and mix from the release by default.
  * Removed RPC and application overlay modules.
  * Updated deps and docs.

## v0.4.0

* Enhancements
  * Support for distillery ~> 2.0
  * Support for Elixir ~> 1.7

## v0.3.1

For Shoehorn, these are our goals:
1: Fix current issue with prod devices turning to zombies
2: Make it really really difficult to enter a brick state ever.

It was becoming apparent that it is difficult to address goal #1 by changing the defaults without impacting goal #2 at all. We believe that its best to solve goal #1  by opting in and not by modifying the defaults.

In this release, existing projects that do not declare a handler in the
config will use `Shoehorn.Handler.Ignore`.

## v0.3.0

The default strategy for how Shoehorn handles OTP application exits has changed.
Before this release, if an application were to exit the node would remain running
and that applications would remain stopped. This may be desireable for development
and test but is typically undesirable in production. This behaviour can be
customized by configuring the `handler` in the config. For example, in dev you can
use the module `Shoehorn.Handler.Ignore` to prevent the node from halting on failure.

  ```elixir
  # config/dev.exs

  config :shoehorn,
    handler: Shoehorn.Handler.Ignore
  ```

Check out the [example application](https://github.com/nerves-project/shoehorn/tree/main/example) for information on implementing custom strategies.

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
