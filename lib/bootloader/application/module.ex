defmodule Bootloader.Application.Module do
  defstruct [name: nil, hash: nil, binary: nil]

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

  def compare(sources, targets) when is_list(sources) and is_list(targets) do
    modified =
      Enum.reduce(sources, [], fn(s, acc) ->
        t = Enum.find(targets, & &1.name == s.name)
        case compare(s, t) do
          {:noop, _} -> acc
          modification -> [modification | acc]
        end
      end)
    deleted =
      Enum.reduce(targets, [], fn(t, acc) ->
        if Enum.any?(sources, & &1.name == t.name) do
          acc
        else
          [{:deleted, t} | acc]
        end
      end)
    modified ++ deleted
  end
  def compare(s, nil), do: {:inserted, s}
  def compare(%{hash: hash} = s, %{hash: hash}), do: {:noop, s}
  def compare(s, _), do: {:modified, s}

end
