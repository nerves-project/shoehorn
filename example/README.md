# Example

This directory contains a set of Elixir projects to demonstrate Shoehorn. The
`my_project` directory contains the main project. It depends on the other
projects which exercise different aspects of Shoehorn:

* `crash_app` - this project crashes in its `Application.start/2` callback
* `load_only_app` - this project is marked as a load-only app in `my_project`'s
  `mix.exs`
* `optional_app` - this project is marked optional in `my_project`'s `mix.exs`
* `pure_library` - this project doesn't have an `Application.start/2` callback
* `some_app` - this is a trivial project with an `Application.start/2` callback
* `system_init` - this project is configured to load as early as possible in
  `my_project`'s `config.exs`

## Building and running

```bash
cd my_project
mix deps.get
mix release
RELEASE_BOOT_SCRIPT=shoehorn _build/dev/rel/my_project/bin/my_project start_iex
```

Take a look at `_build/dev/rel/my_project/releases/0.1.0/shoehorn.script` for
how Shoehorn starts it up. The calls to `:application.start_boot/2` at the end
are useful. Many applications will be marked as `:temporary` and those are the
ones that you can now handle in your code with `Shoehorn.Handler`
implementations.

## Handling application stops

Stop the main application, and watch the `MyProject.RestartHandler` restart it.

```elixir
iex> Application.stop(:my_project)

:ok
iex> Application stopped: :my_project %{restart_counts: 0}
MyProject start
Application started: :my_project
```

After 5 crashes, the vm will exit.

```elixir
iex> Application.stop(:my_project)

15:37:58.192 [info]  Application my_project exited: :stopped
Application stopped forever: :my_project %{restart_counts: 4}
:ok
```
