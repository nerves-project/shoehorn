defmodule LoadOnlyApp.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    Logger.error("The load_only app was started!")

    children = [
      # Starts a worker by calling: LoadOnlyApp.Worker.start_link(arg)
      # {LoadOnlyApp.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LoadOnlyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
