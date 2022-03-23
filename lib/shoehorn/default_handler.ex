defmodule Shoehorn.DefaultHandler do
  @moduledoc """
  Default handler that ignores all events
  """
  @behaviour Shoehorn.Handler

  @impl Shoehorn.Handler
  def init(_opts) do
    {:ok, :no_state}
  end

  @impl Shoehorn.Handler
  def application_started(_app, state) do
    {:continue, state}
  end

  @impl Shoehorn.Handler
  def application_exited(_app, _reason, state) do
    {:continue, state}
  end
end
