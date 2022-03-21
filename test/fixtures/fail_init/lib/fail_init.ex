defmodule FailInit do
  @moduledoc false
  require Logger

  def start(_, _) do
    Logger.warn("FailInit.start/2 Called")
    :error = "error"
  end
end
