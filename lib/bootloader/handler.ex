defmodule Bootloader.Handler do

  @callback init() :: any

  @callback application_stopped(app :: atom, reason:: any, state :: any) ::
    {:noreply, state :: any} |
    {:stop, reason :: term, state :: any}

  defmacro __using__(_) do
    quote do
      @behaviour Bootloader.Handler
    end
  end

  def init() do
    IO.puts """
      Bootloader Handler Init
    """
    nil
  end

  def handle_application(app, response, s) do
    IO.puts """
      Bootloader Application Responded:
      #{inspect response}
    """
    {:noreply, s}
  end
end
