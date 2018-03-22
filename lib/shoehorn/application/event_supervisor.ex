defmodule Shoehorn.Application.EventSupervisor do
  @moduledoc false

  @behaviour :gen_event
  @shutdown_timer 30_000

  def init(opts) do
    handler = opts[:handler] || Shoehorn.Handler.Default
    shutdown_timer = opts[:shutdown_timer] || @shutdown_timer
    
    {:ok, handler_state} = handler.init(opts)
    {:ok, %{
      handler: handler,
      handler_state: handler_state,
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
    try do
      case apply(s.handler, :application_exited, [app, reason, s.handler_state]) do
        {:halt, _handler_state} ->
          :erlang.halt()
        {:continue, handler_state} ->
          :timer.cancel(shutdown_timer_ref)
          %{s | handler_state: handler_state}
      end
    rescue
      e ->
        IO.puts("Shoehorn handler raised an exception: #{inspect e}")
        IO.puts("halt")
        :erlang.halt()
    end
  end

  defp started(app, s) do
    try do
      case apply(s.handler, :application_started, [app, s.handler_state]) do
        {:halt, _handler_state} ->
          :erlang.halt()
        {:continue, handler_state} ->
          %{s | handler_state: handler_state}
      end
    rescue 
      e ->
        IO.puts("Shoehorn handler raised an exception: #{inspect e}")
        IO.puts("continue")
    end
  end
end
