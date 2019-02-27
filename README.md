# Shoehorn

[![CircleCI](https://circleci.com/gh/nerves-project/shoehorn.svg?style=svg)](https://circleci.com/gh/nerves-project/shoehorn)
[![Hex version](https://img.shields.io/hexpm/v/shoehorn.svg "Hex version")](https://hex.pm/packages/shoehorn)

Shoehorn provides full control over the application lifecycle in Elixir.

## Usage

`Shoehorn` acts as a shim to the initialization sequence for your application's
VM. Using `Shoehorn`, you can ensure that the VM will always pass initialization.
This provides the running node the ability of using Elixir / Erlang to control
the full application lifecycle through the exposure of new system phases.
This level of control is important when the Erlang VM is fully responsible
for the entire runtime including its own updates. In these situations, if
the VM were to fail to start it would never be able to recover from a bad
update. This is especially useful when running [Nerves](https://circleci.com/gh/nerves-project).

Here's how it works.

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

Booting the shoehorn.boot script with zero application config will bring up the 
Erlang VM and only run the `shoehorn` app.

Now let's configure `shoehorn` to do something more interesting by adding some
minimal configuration.

```elixir
# config/config.exs

config :shoehorn,
  app: :my_app,
  init: [:nerves_runtime, :nerves_init_gadget, :nerves_firmware_ssh]
```

Shoehorn will call `Application.ensure_all_started/2` on each app in the `init`
list, followed by the main `app`. In the example above, the boot sequence would be 
`[:nerves_runtime, :nerves_init_gadget, :my_app]`. The `init` application list
should be used to prioritize OTP applications that need to be available to recover
from error. In the example above, we initialize the runtime, bring up the network, 
and ensure we can receive new firmware updates. If `my_app` were to fail to start,
the node would still be in a state where it can receive new firmware over the network.

You can also specify an `{m, f, a}` in the init list for performing 
simple initialization time tasks.

```elixir
# config/config.exs

config :shoehorn,
  app: :my_app,
  init: [{IO, :puts, "Init"}, :nerves_runtime]
```

## Application Failures

The Erlang VM will respond to application failures based off the application start 
permanence type specified when it was asked to start. There are three permanence types: 

  `:permanent` - if app terminates, all other applications and the entire node are also terminated.

  `:transient` - if app terminates with :normal reason, it is reported but no other applications 
  are terminated. If a transient application terminates abnormally, all other applications and the 
  entire node are also terminated.

  `:temporary` - if app terminates, it is reported but no other applications are terminated (the default).

Shoehorn will start all applications as `:temporary` and monitor application events by registering 
to the erlang kernel [error_logger](http://erlang.org/doc/man/error_logger.html). Application start 
and exit events will attempt to execute a callback to the configured `Shoehorn.Handler` module. By default, 
the module `Shoehorn.Handler.Ignore` will be called. This module is configured to continue the Erlang VM 
if any otp application were to exit for any reason. In production, you may want to customize the action on 
failure so you can gather forensics or perform updates to the node. You can do this by overriding the 
handler in the prod env of your application config.

```elixir
# config/prod.exs

config :shoehorn,
  handler: MyApp.ShoehornHandler
```

More advanced failure cases can be handled by providing your own module that implements
the `Shoehorn.Handler` behaviour. For example, the erlang `:ssh` application is prone to
exiting when undergoing a brute force attack. Instead of the default production behaviour of
forcing the node to restart, we can restart the application.

```
defmodule Example.RestartHandler do
  use Shoehorn.Handler

  def application_exited(app, _reason, state) do
    IO.puts("Application stopped: #{inspect(app)} #{inspect(state)}")
    Application.ensure_all_started(app)
    {:continue, state}
  end

end
```

The `application_exited/3` callback is limited in the amount of time is has to execute by
setting a shutdown timer. If the callback does not return within the defined shutdown time,
the node is instructed to halt. The default shutdown time is 30 seconds but this value can
be changed in the application config.

```elixir
# config/config.exs

config :shoehorn,
  shutdown_timer: 50_000 # 50 Seconds
```

Check out the [example application](https://github.com/nerves-project/shoehorn/tree/master/example) for more info on implementing custom strategies. 

## Thanks
Big thanks to [Sonny Scroggin](https://github.com/scrogson) for coming up with
the name Shoehorn <3
