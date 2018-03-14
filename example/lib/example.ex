defmodule Example do
  def start(_, _) do
    IO.puts "Example start"
    {:ok, self()}
  end
end
