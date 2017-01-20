defmodule Bootloader.Application.PrivDir do
  alias Bootloader.Utils
  alias __MODULE__

  defstruct [application: nil, hash: nil, path: nil, files: []]

  @type t :: %__MODULE__{
    application: atom,
    hash: String.t,
    path: String.t,
    files: Bootloader.Application.PrivDir.File.t
  }

  def load(app) do
    path =
      if exists?(app) do
        path(app)
      else
        nil
      end
    %__MODULE__{
      application: app,
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

  def apply(%__MODULE__{} = pd, overlay_path) do
    path = path(pd.application)
    files = files(path)
    # Check to see if there is work to perform.
    if (files != [] or pd.files != []) do
      overlay_priv_dir =
        Path.join(overlay_path, "priv")
      File.mkdir_p!(overlay_priv_dir)

      # Copy the current priv dir contents if it is not empty
      # Erlang always bases the priv dir off the first location it resolves from
      #  :code.get_path
      if files != [] do
        File.cp_r!(path, overlay_priv_dir)
      end

      # Apply the changes to the new priv_dir
      Enum.each(pd.files, &PrivDir.File.apply(&1, overlay_priv_dir))

      # Update the code path to include the directory parent
      Path.join(overlay_path, "ebin")
      |> Code.prepend_path()
    else
      :noop
    end
  end

end
