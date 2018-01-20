defmodule Shoehorn.Handler do

  @callback init() :: any

  @callback application_stopped(app :: atom, reason:: any, state :: any) ::
    {:noreply, state :: any} |
    {:stop, reason :: term, state :: any}

  defmacro __using__(_) do
    quote do
      @behaviour Shoehorn.Handler
    end
  end

  def init() do
    nil
  end

  def handle_application(_app, _response, s) do
    {:noreply, s}
  end
end
