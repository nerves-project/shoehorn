# Shoehorn

[![CircleCI](https://circleci.com/gh/nerves-project/shoehorn.svg?style=svg)](https://circleci.com/gh/nerves-project/shoehorn)
[![Hex version](https://img.shields.io/hexpm/v/shoehorn.svg "Hex version")](https://hex.pm/packages/shoehorn)

Shoehorn helps you handle OTP application failures

## Motivation

By default, the Erlang VM exits when OTP applications unexpectedly stop. This
can happen if an application's `Application.start/2` callback crashes or if a
`GenServer` crashes repeatedly and takes down the application's supervision
tree. Either way, recovery needs to happen outside of the Erlang VM.

Shoehorn provides a way of handling this inside the Erlang VM to allow you to
debug, restart an application, switch to a recovery mode, or something else of
your choosing. It does this by creating a custom release start script
(`shoehorn.boot`) and exposing the `Shoehorn.Handler` behaviour for your code to
decide what to do. The custom release start script turns off the default OTP
application mode that exits the VM on unexpected errors and orders application
starts to make sure that the handler is available.

Shoehorn has another benefit of letting you influence the OTP application start
order. Dependencies still determine the overall ordering, but it's possible to
sort applications earlier via Shoehorn's `:init` option. This can let you
improve the apparent release startup time on slow platforms.

## Usage

Run `mix release.init` on your project and then add `shoehorn` to your `mix
releases` configuration in the `mix.exs` (replace `:my_app`):

```elixir
  def project do
    [
      ...
      releases: releases()
    ]
  end

  def releases do
    [
      my_app: [
        steps: [&Shoehorn.Release.init/1, :assemble]
      ]
    ]
  end

  defp deps do
    [
      {:shoehorn, "~> 0.7.0"}
    ]
  end
end
```

Create a release:

```sh
mix release
```

Next, run your app using `shoehorn`:

```sh
_build/dev/rel/simple_app/bin/simple_app console_boot $(pwd)/_build/dev/rel/simple_app/bin/shoehorn
```

From here we can see that shoehorn was started, but `simple_app` was not.

```elixir
iex(simple_app@127.0.0.1)1> Application.started_applications
[{:iex, 'iex', '1.4.0'}, {:shoehorn, 'shoehorn', '0.1.0'},
 {:elixir, 'elixir', '1.4.0'}, {:compiler, 'ERTS  CXC 138 10', '7.0.3'},
 {:stdlib, 'ERTS  CXC 138 10', '3.2'}, {:kernel, 'ERTS  CXC 138 10', '5.1.1'}]
```

Booting the shoehorn.boot script with zero application config will bring up the
Erlang VM and only run the `shoehorn` app.

Now let's configure `shoehorn` to do something more interesting by adding some
minimal configuration:

```elixir
# config/config.exs

config :shoehorn,
  init: [:nerves_runtime, :nerves_pack]
```

Shoehorn will generate a release script that starts `:nerves_runtime` and its
dependencies as soon as it can. Then it will start `:nerves_pack` and its
dependencies. Then it will start the remainder of the applications in the
project.

Use the `init` application list to prioritize OTP applications that are needed
for error recovery. In the example above, we initialize the runtime, bring up
the network, and ensure that we can receive new firmware updates. Now, if
`my_app` fails to start, the node would still be in a state where it can receive
new firmware over the network.

```elixir
# config/config.exs

config :shoehorn,
  init: [:nerves_runtime]
```

## Application Failures

The Erlang VM will respond to application failures differently, depending on the
_mode_ specified when the application started. The modes are:

* `:permanent` - if the application terminates, all other applications and the
  entire node are also terminated.
* `:transient` - if the application terminates with `:normal reason`, it is
  reported but no other applications are terminated. However, if the application
  terminates abnormally, all other applications and the entire node are also
  terminated.
* `:temporary` - if the application terminates, it is reported but no other
  applications are terminated (the default behaviour).

Unless overridden in the Mix release, Shoehorn starts all applications as
`:temporary` and monitors application events by registering with the erlang
kernel [error_logger](http://erlang.org/doc/man/error_logger.html).

Application start and exit events will attempt to execute a callback to the
configured `Shoehorn.Handler` module. By default, the module
`Shoehorn.DefaultHandler` will be called. This module is configured to continue
the Erlang VM if any OTP application were to exit, for any reason. In
production, you may want to customize the action on failure so you can gather
forensics or perform updates to the node.  You can do this by overriding the
handler in the prod env of your application config.

```elixir
# config/prod.exs

config :shoehorn,
  handler: MyApp.ShoehornHandler
```

More advanced failure cases can be handled by providing your own module that
implements the `Shoehorn.Handler` behaviour. For example, the erlang `:ssh`
application is prone to exiting when undergoing a brute force attack. Instead of
the default production behaviour of forcing the node to restart, we can restart
the application.

```elixir
defmodule Example.RestartHandler do
  @behavior Shoehorn.Handler

  def init(_opts) do
    {:ok, nil}
  end

  def application_started(_app, state) do
    {:continue, state}
  end

  def application_exited(app, _reason, state) do
    Logger.error("Application stopped: #{inspect(app)} #{inspect(state)}")
    Application.ensure_all_started(app)
    {:continue, state}
  end
end
```

The `application_exited/3` callback is limited in the amount of time is has to
execute by setting a shutdown timer. If the callback does not return within the
defined shutdown time, the node is instructed to halt. The default shutdown time
is 30 seconds but this value can be changed in the application config:

```elixir
# config/config.exs

config :shoehorn,
  shutdown_timer: 50_000 # 50 Seconds
```

Have a look at the [example
application](https://github.com/nerves-project/shoehorn/tree/main/example) for
more info on implementing custom strategies.
