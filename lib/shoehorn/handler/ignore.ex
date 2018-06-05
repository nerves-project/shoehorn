defmodule Shoehorn.Handler.Ignore do
  @moduledoc false
  use Shoehorn.Handler

  def init(_opts) do
    {:ok, :no_state}
  end

  def application_started(_app, state) do
    {:continue, state}
  end

  def application_exited(_app, _reason, state) do
    {:continue, state}
  end
end
