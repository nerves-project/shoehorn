# SPDX-FileCopyrightText: 2018 Amos L King
# SPDX-FileCopyrightText: 2021 Frank Hunleth
# SPDX-FileCopyrightText: 2024 Alan Jackson
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Shoehorn.ReportHandler do
  @moduledoc false

  alias Shoehorn.Handler
  use GenServer

  @shutdown_timer 30_000

  @spec init_handler() :: :ok
  def init_handler() do
    current_filters = :logger.get_primary_config() |> find_filters()

    shoehorn_filters = [
      shoehorn_filter: {&Shoehorn.Filter.filter/2, []}
    ]

    # Put the shoehorn filter to the front of the list to make sure it handles
    # the message first.

    # Note: Ignore errors since this isn't a good place to raise and if logging
    # is not working, then logging an error won't help.
    _ = :logger.set_primary_config(:filters, shoehorn_filters ++ current_filters)
    :ok
  end

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(opts) do
    shutdown_timer = opts[:shutdown_timer] || @shutdown_timer
    state = %{handler: Handler.init(opts), shutdown_timer: shutdown_timer}
    {:ok, state}
  end

  @impl GenServer
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
