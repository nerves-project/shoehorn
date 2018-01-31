# Shoehorn

[![CircleCI](https://circleci.com/gh/nerves-project/shoehorn.svg?style=svg)](https://circleci.com/gh/nerves-project/shoehorn)
[![Hex version](https://img.shields.io/hexpm/v/shoehorn.svg "Hex version")](https://hex.pm/packages/shoehorn)

Shoehorn provides full control over the application lifecycle in Elixir.

## Usage

`Shoehorn` acts as a shim to the initialization sequence for your application's
VM. Using `Shoehorn`, you can ensure that the VM will always pass initialization.
This provides the running target the ability of using Elixir / Erlang to control
the full application lifecycle through the exposure of new system phases.

Heres how it works.
Include `shoehorn` into your application release plugins.
```elixir
# rel/config.exs

release :simple_app do
  set version: current_version(:simple_app)
  plugin Shoehorn
end
```

And produce a release
```sh
$ mix release
```

Go to the release directory and boot your app using `shoehorn`
```sh
$ _build/dev/rel/simple_app/bin/simple_app console_boot shoehorn
```

From here we can see that the shoehorn was started, but `simple_app` was not.
```elixir
iex(simple_app@127.0.0.1)1> Application.started_applications
[{:iex, 'iex', '1.4.0'}, {:shoehorn, 'shoehorn', '0.1.0'},
 {:elixir, 'elixir', '1.4.0'}, {:compiler, 'ERTS  CXC 138 10', '7.0.3'},
 {:stdlib, 'ERTS  CXC 138 10', '3.2'}, {:kernel, 'ERTS  CXC 138 10', '5.1.1'}]
```

Now lets configure `shoehorn` to do something more interesting by adding some
general configuration.

Lets have it start our application and initialize some apps before our app starts
```elixir
# config/config.exs

config :shoehorn,
  overlay_path: "/tmp/erl_shoehorn",
  init: [:runtime_app],
  app: :simple_app
```

## Thanks
Big thanks to [Sonny Scroggin](https://github.com/scrogson) for coming up with
the name Shoehorn <3
