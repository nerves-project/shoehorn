defmodule Shoehorn.ApplicationController do
  use GenServer

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(opts) do
    init = opts[:init] || []

    s = %{
      init: init,
      status: :init
    }

    send(self(), :init)
    {:ok, s}
  end

  # Shoehorn Application Init Phase
  @impl GenServer
  def handle_info(:init, s) do
    Enum.each(s.init, &start_app/1)
    {:noreply, %{s | status: :app}}
  end

  def handle_info(_unknown, s) do
    {:noreply, s}
  end

  defp start_app({m, f, a}) when is_list(a) do
    apply(m, f, a)
  end

  defp start_app(app) when is_atom(app) do
    # _ = Application.ensure_all_started(app)
  end

  defp start_app(init_call) do
    IO.puts("""
    Shoehorn encountered an error while trying to call #{inspect(init_call)}
    during initialization. The argument needs to be formatted as

    {Module, :function, [args]}
    :application
    """)

    :ok
  end
end
