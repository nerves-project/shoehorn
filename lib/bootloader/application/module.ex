defmodule Bootloader.Application.Module do
  defstruct [name: nil, hash: nil]

  def load(mod) do
    %__MODULE__{
      name: mod,
      hash: hash(mod)
    }
  end

  defp hash(mod) do
    case mod.module_info(:attributes)[:vsn] do
      [vsn] -> vsn
      _ -> mod.module_info(:md5) |> Base.encode16
    end
  end

end
