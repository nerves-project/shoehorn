defmodule Bootloader.Application.PrivDir.File do
  alias Bootloader.Utils

  defstruct [path: nil, hash: nil, binary: nil]

  def load(path, dir) do
    hash =
      Path.join(dir, path)
      |> File.read!
      |> Utils.hash
    %__MODULE__{
      path: path,
      hash: hash
    }
  end

  def compare(sources, targets) when is_list(sources) and is_list(targets) do
    IO.inspect sources
    IO.inspect targets
    modified =
      Enum.reduce(sources, [], fn(s, acc) ->
        t = Enum.find(targets, fn(t) -> t.path == s.path end)
        case compare(s, t) do
          {:noop, _} -> acc
          modification -> [modification | acc]
        end
      end)
    deleted =
      Enum.reduce(targets, [], fn(t, acc) ->
        if Enum.any?(sources,  fn(s) -> s.path == t.path end) do
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

  def apply(:inserted, file) do

  end
  def apply(:deleted, file) do

  end
  def apply(:modified, file) do

  end
end
