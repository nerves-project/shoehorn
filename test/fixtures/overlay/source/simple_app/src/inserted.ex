defmodule SimpleApp.Inserted do
  def ping do
    {__MODULE__, :source, :pong}
  end
end
