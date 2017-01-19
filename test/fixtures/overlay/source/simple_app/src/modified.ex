defmodule SimpleApp.Modified do
  def ping do
    {__MODULE__, :source, :pong}
  end
end
