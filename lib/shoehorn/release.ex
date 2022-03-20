defmodule Shoehorn.Release do
  @moduledoc false

  # These applications are unrecoverable using shoehorn
  @permanent_applications [
    :shoehorn,
    :runtime_tools,
    :kernel,
    :stdlib,
    :compiler,
    :elixir,
    :iex,
    :crypto,
    :logger,
    :sasl
  ]

  @spec init(Mix.Release.t()) :: Mix.Release.t()
  def init(release) do
    init_apps = Application.get_env(:shoehorn, :init, [])

    all_apps = collect_all_applications(release)
    all_init_apps = all_init_applications(release, init_apps)
    sorted_apps = sort_applications(all_apps, all_init_apps)

    new_boot_scripts = Map.put(release.boot_scripts, :shoehorn, sorted_apps)

    %{release | boot_scripts: new_boot_scripts}
  end

  defp collect_all_applications(release) do
    Enum.map(release.applications, fn {name, _properties} ->
      mode = if name in @permanent_applications, do: :permanent, else: :temporary
      {name, mode}
    end)
  end

  # Compute the transitive closure of the init apps
  defp all_init_applications(release, init_apps) do
    init_apps
    |> Enum.reduce(MapSet.new(), fn app, acc ->
      if is_atom(app) do
        release.applications[app].applications
        |> MapSet.new()
        |> MapSet.union(acc)
      else
        # skip non-apps
        acc
      end
    end)
  end

  defp sort_applications(apps, init_apps) do
    Enum.sort(apps, &app1_before_wrap(&1, &2, init_apps))
  end

  defp app1_before_wrap(app1, app2, init_apps) do
    result = app1_before(app1, app2, init_apps)
    IO.puts("#{inspect(app1)} < #{inspect(app2)} ? #{result}")
    result
  end

  defp app1_before({app1, _}, {app2, _}, init_apps) do
    app1_is_shoehorn? = app1 in @permanent_applications
    app2_is_shoehorn? = app2 in @permanent_applications

    cond do
      app1 == :iex ->
        false

      app2 == :iex ->
        true

      app1_is_shoehorn? and app2_is_shoehorn? ->
        app1 < app2

      app1_is_shoehorn? ->
        true

      app2_is_shoehorn? ->
        false

      true ->
        app1_is_init? = MapSet.member?(init_apps, app1)
        app2_is_init? = MapSet.member?(init_apps, app2)

        cond do
          app1_is_init? == app2_is_init? -> app1 < app2
          app1_is_init? -> true
          true -> false
        end
    end
  end
end
