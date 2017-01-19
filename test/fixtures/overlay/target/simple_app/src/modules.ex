defmodule SimpleApp.Modified do
  def ping do
    {__MODULE__, :target, :pong}
  end
end

defmodule SimpleApp.Deleted do
  def ping do
    {__MODULE__, :target, :pong}
  end
end
