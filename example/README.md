# Example

## Build using Elixir Releases (Elixir >= 1.9.0)

```bash
mix deps.get
mix release
RELEASE_BOOT_SCRIPT=shoehorn _build/dev/rel/example/bin/example start_iex
```

## Build using Distillery (Elixir < 1.9)

```bash
mix deps.get
mix distillery.release
_build/dev/rel/example/bin/example console_boot $(pwd)/_build/dev/rel/example/bin/shoehorn
```

## Handling application stops

Stop the main application, and watch the `Example.RestartHandler` restart it.

```elixir
iex> Application.stop(:example)

:ok
iex> Application stopped: :example %{restart_counts: 0}
Example start
Application started: :example
```

After 5 crashes, the vm will exit.

```elixir
iex> Application.stop(:example)

15:37:58.192 [info]  Application example exited: :stopped
Application stopped forever: :example %{restart_counts: 4}
:ok
```
