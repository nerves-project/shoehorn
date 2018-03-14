defmodule Shoehorn.Application do
  alias Shoehorn.Utils

  defstruct name: nil, hash: nil, priv_dir: nil, applications: [], modules: []

  @type t :: %__MODULE__{
          name: atom,
          hash: String.t(),
          priv_dir: Shoehorn.Application.PrivDir.t()
        }

  def load(app) do
    applications = applications(app)
    modules = modules(app)
    priv_dir = priv_dir(app)
    hash = hash(modules, priv_dir)

    %__MODULE__{
      name: app,
      applications: applications,
      modules: modules,
      hash: hash,
      priv_dir: priv_dir
    }
  end

  def hash(modules, priv_dir) do
    blob =
      (modules ++ [priv_dir])
      |> Enum.map(& &1.hash)
      |> Enum.join()

    :crypto.hash(:sha256, blob)
    |> Base.encode16()
  end

  def applications(app) do
    spec = spec(app)

    application_list =
      Keyword.get(spec, :applications, []) ++
        Keyword.get(spec, :included_applications, []) ++
        Keyword.get(spec, :extra_applications, [])

    # |> expand_applications(application_list)
    application_list
    |> Enum.uniq()
    |> Enum.reject(&(&1 in Utils.shoehorn_applications()))

    # |> Enum.map(&Shoehorn.Application.load/1)
  end

  def expand_applications([], l), do: List.flatten(l)

  def expand_applications(list, loaded) do
    list =
      Enum.map(list, &Shoehorn.Application.applications/1)
      |> List.flatten()

    loaded =
      [list | loaded]
      |> List.flatten()
      |> Enum.uniq()

    expand_applications(list, loaded)
  end

  def modules(app) do
    spec(app)[:modules]
    |> Enum.map(&Shoehorn.Application.Module.load(app, &1))
  end

  def priv_dir(app) do
    Shoehorn.Application.PrivDir.load(app)
  end

  def spec(app) do
    try do
      {:ok, application_spec} =
        Path.join([ebin(app), "#{app}.app"])
        |> :file.consult()

      {_, _, application_spec} =
        Enum.find(application_spec, fn
          {:application, ^app, _} -> true
          _ -> false
        end)

      application_spec
    rescue
      _ ->
        Application.load(app)
        Application.spec(app)
    end
  end

  def lib_dir(app) do
    :code.lib_dir(app)
  end

  def ebin(app) do
    build_ebin = Path.join([lib_dir(app), "ebin"])

    if File.dir?(build_ebin) do
      build_ebin
    else
      Path.join([:code.lib_dir(app), "ebin"])
    end
  end

  def compare(sources, targets) when is_list(sources) and is_list(targets) do
    modified =
      Enum.reduce(sources, [], fn s, acc ->
        t = Enum.find(targets, &(&1.name == s.name))

        case compare(s, t) do
          {:noop, _} ->
            acc

          {mod, s} ->
            modules =
              Shoehorn.Application.Module.compare(s.modules, t.modules)
              |> Enum.map(fn
                {action, mod} when action in [:modified, :inserted] ->
                  {action, %{mod | binary: Shoehorn.Application.Module.bin(s.name, mod)}}

                mod ->
                  mod
              end)

            priv_dir = Shoehorn.Application.PrivDir.compare(s.priv_dir, t.priv_dir)
            mod = {mod, %{s | modules: modules, priv_dir: priv_dir}}
            [mod | acc]
        end
      end)

    deleted =
      Enum.reduce(targets, [], fn t, acc ->
        if Enum.any?(sources, &(&1.name == t.name)) do
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

  def apply({:inserted, _app}, _overlay_path) do
  end

  def apply({:deleted, _app}, _overlay_path) do
  end

  def apply({:modified, app}, overlay_path) do
    overlay_path = Path.join([overlay_path, to_string(app.name)])
    Application.stop(app.name)
    Shoehorn.Application.PrivDir.apply(app.priv_dir, overlay_path)
    Enum.each(app.modules, &Shoehorn.Application.Module.apply(&1, overlay_path))
    # Try to start the application. If it fails, we should callback the handler
    #  for more a strategy, like rolling the code path back.
    Application.start(app.name)
  end

  def exists?(nil), do: false

  def exists?(app) do
    case spec(app) do
      nil -> false
      _ -> true
    end
  end
end
