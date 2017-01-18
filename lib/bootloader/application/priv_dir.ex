defmodule Bootloader.Application.PrivDir do
  alias Bootloader.Utils

  defstruct [hash: nil, path: nil]

  def load(app) do
    path =
      if exists?(app) do
        path(app)
      else
        nil
      end
    %__MODULE__{
      hash: hash(path),
      path: path
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
    blob =
      case File.ls(path) do
        {:ok, files} ->
          IO.inspect path
          Utils.expand_paths(files, path)

          |> Enum.map(& File.read!/1)
          |> Enum.map(& Utils.hash/1)
          |> Enum.join
        _ -> ""
      end
    Utils.hash(blob)
  end

end
