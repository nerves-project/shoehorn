defmodule Shoehorn.ReportHandler do
  @moduledoc false
  use GenServer

  alias Shoehorn.Handler

  @shutdown_timer 30_000

  @doc false
  def adding_handler(%{config: opts} = config) do
    {:ok, pid} = GenServer.start_link(__MODULE__, opts)
    {:ok, %{config | config: %{pid: pid}}}
  end

  @doc false
  def removing_handler(%{config: %{pid: pid}}) do
    GenServer.stop(pid)
  end

  @doc false
  def log(
        %{msg: {:report, %{label: {:application_controller, :progress}, report: report}}},
        config
      ) do
    application = Keyword.get(report, :application)
    GenServer.cast(config.config.pid, {:start, application})
  end

  def log(%{msg: {:report, %{label: {:application_controller, :exit}, report: report}}}, config) do
    application = Keyword.get(report, :application)
    reason = Keyword.get(report, :exited)
    GenServer.cast(config.config.pid, {:exit, application, reason})
  end

  def log(_log, _config), do: :ok

  @impl GenServer
  def init(opts) do
    shutdown_timer = opts[:shutdown_timer] || @shutdown_timer
    {:ok, %{handler: Handler.init(opts), shutdown_timer: shutdown_timer}}
  end

  @impl GenServer
  def handle_call(_, _, state) do
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_cast({:start, application}, state) do
    {:noreply, started(application, state)}
  end

  def handle_cast({:exit, application, reason}, state) do
    {:noreply, exited(application, reason, state)}
  end

  def handle_cast(_, state) do
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(_, state) do
    {:noreply, state}
  end

  @impl GenServer
  def terminate(_reason, _state) do
    :ok
  end

  defp exited(app, reason, state) do
    {:ok, shutdown_timer_ref} = :timer.apply_after(state.shutdown_timer, :erlang, :halt, [])

    return =
      :application_exited
      |> Handler.invoke(app, reason, state.handler)
      |> react(state)

    _ = :timer.cancel(shutdown_timer_ref)
    return
  end

  defp started(app, state) do
    :application_started
    |> Handler.invoke(app, state.handler)
    |> react(state)
  end

  defp react({:halt, _}, _), do: :erlang.halt()
  defp react({:continue, handler}, state), do: %{state | handler: handler}
end
