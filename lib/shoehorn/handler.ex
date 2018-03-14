defmodule Shoehorn.Handler do
  @callback application_stopped(app :: atom) :: any

  defmacro __using__(_) do
    quote do
      @behaviour Shoehorn.Handler
    end
  end

  def application_stopped(_app) do
    :ok
  end
end
