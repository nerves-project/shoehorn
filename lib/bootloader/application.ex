defmodule Bootloader.Application do
  alias Bootloader.Utils

  defstruct [name: nil, hash: nil, priv_dir: nil, applications: [], modules: []]

  @type t :: %__MODULE__{
    name: atom,
    hash: String.t,
    priv_dir: Bootloader.Application.PrivDir.t
  }

  def load(app) do
    Application.load(app)
    applications = applications(app)
    modules = modules(app)
    priv_dir = priv_dir(app)
    hash = hash(modules, applications, priv_dir)
    %__MODULE__{
      name: app,
      applications: applications,
      modules: modules,
      hash: hash,
      priv_dir: priv_dir
    }
  end

  def hash(modules, applications, priv_dir) do
    blob =
      (modules ++ applications ++ [priv_dir])
      |> Enum.map(& &1.hash)
      |> Enum.join

    :crypto.hash(:sha256, blob)
    |> Base.encode16
  end

  defp applications(app) do
    spec = Application.spec(app)
    applications =
      Keyword.get(spec, :applications, []) ++
      Keyword.get(spec, :included_applications, [])
    applications = Enum.reject(applications, & &1 in Utils.bootloader_applications())
    Enum.map(applications, &Bootloader.Application.load/1)
  end

  def modules(app) do
    Application.spec(app)[:modules]
    |> Enum.map(&Bootloader.Application.Module.load/1)
  end

  def priv_dir(app) do
    Bootloader.Application.PrivDir.load(app)
  end

  def compare(sources, targets) when is_list(sources) and is_list(targets) do
    modified =
      Enum.reduce(sources, [], fn(s, acc) ->
        t = Enum.find(targets, & &1.name == s.name)
        case compare(s, t) do
          {:noop, _} -> acc
          {mod, s} ->
            modules =
              Bootloader.Application.Module.compare(s.modules, t.modules)
              |> Enum.map(fn
                {action, mod} when action in [:modified, :inserted] ->
                  IO.inspect mod.name
                  {_, bin, _} = :code.get_object_code(mod.name)
                  {action, %{mod | binary: bin}}
                mod -> mod
              end)
            priv_dir = Bootloader.Application.PrivDir.compare(s.priv_dir, t.priv_dir)
            mod = {mod, %{s | modules: modules, priv_dir: priv_dir}}
            [mod | acc]
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

  def apply({:inserted, _app}) do

  end
  def apply({:deleted, _app}) do

  end
  def apply({:modified, app}, overlay_path) do
    overlay_path = Path.join([overlay_path, to_string(app.name)])
    Application.stop(app.name)
    Bootloader.Application.PrivDir.apply(app.priv_dir, overlay_path)
    Enum.each(app.modules, &Bootloader.Application.Module.apply(&1, overlay_path))
    # Try to start the application. If it fails, we should callback the handler
    #  for more a strategy, like rolling the code path back.
    Application.start(app.name)
  end
end
