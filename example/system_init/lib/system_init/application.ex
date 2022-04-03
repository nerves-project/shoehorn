defmodule SystemInit.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("System initialization application started!")

    children = [
      # Starts a worker by calling: SystemInit.Worker.start_link(arg)
      # {SystemInit.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SystemInit.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
