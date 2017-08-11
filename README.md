# Bootloader

[![CircleCI](https://circleci.com/gh/nerves-project/bootloader.svg?style=svg)](https://circleci.com/gh/nerves-project/bootloader)
[![Hex version](https://img.shields.io/hexpm/v/bootloader.svg "Hex version")](https://hex.pm/packages/bootloader)

Bootloader provides full control over the application lifecycle in Elixir.

## Usage

`Bootloader` acts as a shim to the initialization sequence for your application's
VM. Using `Bootloader`, you can ensure that the VM will always pass initialization.
This provides the running target the ability of using Elixir / Erlang to control
the full application lifecycle through the exposure of new system phases.

Heres how it works.
Include `bootloader` into your application release plugins.
```elixir
# rel/config.exs

release :simple_app do
  set version: current_version(:simple_app)
  plugin Bootloader
end
```

And produce a release
```sh
$ mix release
```

Go to the release directory and boot your app using `bootloader`
```sh
$ _build/dev/rel/simple_app/bin/simple_app console_boot bootloader
```

From here we can see that the bootloader was started, but `simple_app` was not.
```elixir
iex(simple_app@127.0.0.1)1> Application.started_applications
[{:iex, 'iex', '1.4.0'}, {:bootloader, 'bootloader', '0.1.0'},
 {:elixir, 'elixir', '1.4.0'}, {:compiler, 'ERTS  CXC 138 10', '7.0.3'},
 {:stdlib, 'ERTS  CXC 138 10', '3.2'}, {:kernel, 'ERTS  CXC 138 10', '5.1.1'}]
```

Now lets configure `bootloader` to do something more interesting by adding some
general configuration.

Lets have it start our application and initialize some apps before our app starts
```elixir
# config/config.exs

config :bootloader,
  overlay_path: "/tmp/erl_bootloader",
  init: [:runtime_app],
  app: :simple_app
```
