defmodule Shoehorn.Utils do
  @moduledoc false

  def shoehorn_applications() do
    [
      :shoehorn,
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
