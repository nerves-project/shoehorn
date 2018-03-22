defmodule Shoehorn.Handler.Proxy do
  @moduledoc false

  @behaviour :gen_event
  @shutdown_timer 30_000

  alias Shoehorn.Handler

  def init(opts) do
    shutdown_timer = opts[:shutdown_timer] || @shutdown_timer

    {:ok,
     %{
       handler: Handler.init(opts),
       shutdown_timer: shutdown_timer
     }}
  end

  def handle_call(_, s) do
    {:ok, :ok, s}
  end

  def handle_event({:info_report, _pid, {_, :std_info, info}}, s) when is_list(info) do
    case Keyword.get(info, :exited) do
      nil ->
        {:ok, s}

      reason ->
        app = Keyword.get(info, :application)
        {:ok, exited(app, reason, s)}
    end
  end

  def handle_event({:info_report, _pid, {_, :progress, info}}, s) when is_list(info) do
    case Keyword.get(info, :started_at) do
      nil ->
        {:ok, s}

      _node ->
        app = Keyword.get(info, :application)
        {:ok, started(app, s)}
    end
  end

  def handle_event(_event, s) do
    {:ok, s}
  end

  def terminate(_args, _s) do
    :ok
  end

  defp exited(app, reason, s) do
    {:ok, shutdown_timer_ref} = :timer.apply_after(s.shutdown_timer, :erlang, :halt, [])

    return =
      :application_exited
      |> Handler.invoke(app, reason, s.handler)
      |> react(s)

    :timer.cancel(shutdown_timer_ref)
    return
  end

  defp started(app, s) do
    :application_started
    |> Handler.invoke(app, s.handler)
    |> react(s)
  end

  def react({:halt, _}, _), do: :erlang.halt()
  def react({:continue, handler}, state), do: %{state | handler: handler}
end
