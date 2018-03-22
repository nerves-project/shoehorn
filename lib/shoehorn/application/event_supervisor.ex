defmodule Shoehorn.Application.EventSupervisor do
  @moduledoc false
  
  @behaviour :gen_event
  @shutdown_timer 30_000

  def init(opts) do
    handler = opts[:handler] || Shoehorn.Handler
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

  def handle_event({:info_report, _pid, {_, :std_info, info}} = event, s) when is_list(info) do
    case Keyword.get(info, :exited) do
      nil -> 
        {:ok, s}
      reason ->
        app = Keyword.get(info, :application)
        {:ok, shutdown(app, reason, s)}
    end
  end

  def handle_event(_event, s) do
    {:ok, s}
  end

  def terminate(_args, _s) do
    :ok
  end

  defp shutdown(app, reason, s) do
    {:ok, shutdown_timer_ref} = :timer.apply_after(s.shutdown_timer, :erlang, :halt, [])

    case apply(s.handler, :handle_application, [reason, app, s.handler_state]) do
      {:halt, _handler_state} ->
        :erlang.halt()
      {:continue, handler_state} ->
        :timer.cancel(shutdown_timer_ref)
        %{s | handler_state: handler_state}
    end
  end
end
