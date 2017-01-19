defmodule Bootloader.Application.Module do
  defstruct [name: nil, hash: nil, binary: nil]

  @type t :: %__MODULE__{
    name: atom,
    hash: String.t | number(),
    binary: binary()
  }

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

  def apply({action, mod}, overlay_path) when action in [:inserted, :modified] do
    ebin_path = Path.join(overlay_path, "ebin")
    File.mkdir_p(ebin_path)

    beam_file = Path.join(ebin_path, "#{mod.name}.beam")
    File.write(beam_file, mod.binary)
    if action == :modified do
      :code.purge(mod.name)
    end

    Code.prepend_path(ebin_path)
    :code.load_file(mod.name)
  end
  def apply({:deleted, mod}, _) do
    :code.delete(mod.name)
    :code.purge(mod.name)
  end

end
