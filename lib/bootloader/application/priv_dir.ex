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

end
