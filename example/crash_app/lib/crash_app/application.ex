defmodule CrashApp.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    raise RuntimeError, "CrashApp is crashing on Application.start"

    children = [
      # Starts a worker by calling: CrashApp.Worker.start_link(arg)
      # {CrashApp.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CrashApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
