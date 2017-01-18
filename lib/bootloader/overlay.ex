defmodule Bootloader.Overlay do
  defstruct [hash: nil, delta: []]

  # @type t :: %__MODULE__{
  #   hash: String.t,
  #   applications: []
  # }

  def load(sources, targets) do
    %__MODULE__{
      delta: Bootloader.Application.compare(sources, targets)
    }
  end

end
