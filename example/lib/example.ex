defmodule Example do
  def start(_, _) do
    {:ok, self()}
  end

  def application_stopped(app) do
    IO.puts "Calling handler from example"
  end
end
