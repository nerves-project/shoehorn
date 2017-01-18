defmodule Bootloader.Application.PrivDir do
  alias Bootloader.Utils

  defstruct [hash: nil, path: nil, files: []]

  def load(app) do
    path =
      if exists?(app) do
        path(app)
      else
        nil
      end
    %__MODULE__{
      hash: hash(path),
      path: path,
      files: files(path)
    }
  end

  def path(app) do
    path =
      :code.priv_dir(app)
      |> to_string
    if File.dir?(path) do
      path
    else
      nil
    end
  end

  def exists?(app) do
    app
    |> path()
    |> File.dir?()
  end

  def hash(nil) do
    Utils.hash("")
  end
  def hash(path) do
    files(path)
    |> Enum.map(fn({_, hash}) ->
      hash
    end)
    |> Enum.join
    |> Utils.hash
  end

  def files(nil), do: []
  def files(path) do
    case File.ls(path) do
      {:ok, files} ->
        Utils.expand_paths(files, path)
        |> Enum.map(fn(file) ->
          hash =
            Path.join(path, file)
            |> File.read!
            |> Utils.hash
          {file, hash}
        end)

      _error -> []
    end
  end

  def compare(%__MODULE__{hash: hash} = s, %__MODULE__{hash: hash}),
    do: %{s | files: []}
  def compare(%__MODULE__{files: sources} = s, %__MODULE__{files: targets}) do
    modified =
      Enum.reduce(sources, [], fn({s_file, _} = s, acc) ->
        t = Enum.find(targets, fn({t_file, _}) -> t_file == s_file end)
        case compare(s, t) do
          {:noop, _} -> acc
          modification -> [modification | acc]
        end
      end)
    deleted =
      Enum.reduce(targets, [], fn({t_file, _} = t, acc) ->
        if Enum.any?(sources,  fn({s_file, _}) -> s_file == t_file end) do
          acc
        else
          [{:deleted, t} | acc]
        end
      end)
    %{s | files: (modified ++ deleted)}
  end
  def compare(s, nil), do: {:inserted, s}
  def compare({_, hash} = s, {_, hash}), do: {:noop, s}
  def compare(s, _), do: {:modified, s}
end
