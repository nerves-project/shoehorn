defmodule FailInit do
  def start(_, _) do
    IO.inspect "FailInit.start/2 Called"
    :error = "error"
  end
end
