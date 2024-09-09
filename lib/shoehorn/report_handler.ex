defmodule Shoehorn.ReportHandler do
  @moduledoc false

  alias Shoehorn.Handler
  use GenServer

  @shutdown_timer 30_000

  def init_handler() do
    current_filters = :logger.get_primary_config() |> find_filters()
    shoehorn_filters = [
        shoehorn_filter: {&Shoehorn.Filter.filter/2, []}
      ]
    # put the shoehorn filter to the front of the list to make sure it handles the message first.
    :logger.set_primary_config(:filters, shoehorn_filters ++ current_filters)
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    shutdown_timer = opts[:shutdown_timer] || @shutdown_timer
    state = %{handler: Handler.init(opts), shutdown_timer: shutdown_timer}
    {:ok, state}
  end

  def handle_cast({:exit, app, reason}, s) do
    {:noreply, exited(app, reason, s)}
  end

  def handle_cast({:started, app}, s) do
    {:noreply, started(app, s)}
  end

  defp exited(app, reason, s) do
    {:ok, shutdown_timer_ref} = :timer.apply_after(s.shutdown_timer, :erlang, :halt, [])

    return =
      :application_exited
      |> Handler.invoke(app, reason, s.handler)
      |> react(s)

    _ = :timer.cancel(shutdown_timer_ref)
    return
  end

  defp started(app, s) do
    :application_started
    |> Handler.invoke(app, s.handler)
    |> react(s)
  end

  defp react({:halt, _}, _), do: :erlang.halt()
  defp react({:continue, handler}, state), do: %{state | handler: handler}

  defp find_filters(%{filters: filters}), do: filters
  defp find_filters(_), do: []
end
