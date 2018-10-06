defmodule Shoehorn.Utils do
  def shoehorn_applications() do
    [
      :shoehorn,
      :distillery,
      :artificery,
      :runtime_tools,
      :kernel,
      :stdlib,
      :compiler,
      :elixir,
      :iex,
      :crypto,
      :logger
    ]
  end
end
