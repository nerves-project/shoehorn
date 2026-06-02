defmodule SomeApp.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: SomeApp.Worker.start_link(arg)
      # {SomeApp.Worker, arg}
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SomeApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
