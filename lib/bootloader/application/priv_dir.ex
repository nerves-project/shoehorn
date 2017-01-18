defmodule Bootloader.Application.PrivDir do
  alias Bootloader.Utils
  alias __MODULE__

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
    |> Enum.map(fn(%{hash: hash}) ->
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
        |> Enum.map(&PrivDir.File.load(&1, path))
      _error -> []
    end
  end

  def compare(%__MODULE__{hash: hash} = s, %__MODULE__{hash: hash}),
    do: %{s | files: []}
  def compare(%__MODULE__{files: sources} = s, %__MODULE__{files: targets}) do
    files =
      Bootloader.Application.PrivDir.File.compare(sources, targets)
      |> Enum.map(fn
        {action, file} when action in [:modified, :inserted] ->
          bin =
            Path.join(s.path, file.path)
            |> File.read!
          {action, %{file | binary: bin}}
        mod -> mod
      end)
    %{s | files: files}
  end

end
