defmodule Shoehorn.Application.PrivDir.File do
  alias Shoehorn.Utils

  defstruct [path: nil, hash: nil, binary: nil]

  @type t :: %__MODULE__{
    path: String.t,
    hash: Stirng.t,
    binary: binary()
  }

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

  def apply({action, file}, priv_dir) when action in [:inserted, :modified] do
    Path.join(priv_dir, file.path)
    |> File.write(file.binary)
  end
  def apply({:deleted, file}, priv_dir) do
    Path.join(priv_dir, file.path)
    |> File.rm()
  end

end
