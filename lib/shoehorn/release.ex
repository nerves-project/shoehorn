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
  def init(%Mix.Release{} = release) do
    init_apps = Application.get_env(:shoehorn, :init, [])
    all_init_apps = all_init_applications(release, init_apps)

    # Start with the start script since it applies the user overrides for the
    # start mode (the :applications option in the release).

    apps =
      release.boot_scripts[:start]
      |> Enum.map(&update_start_mode/1)
      |> Enum.sort(&app_compare(&1, &2, all_init_apps))

    new_boot_scripts = Map.put(release.boot_scripts, :shoehorn, apps)

    %{release | boot_scripts: new_boot_scripts}
  end

  defp update_start_mode({app, mode}) do
    new_mode =
      case mode do
        :permanent ->
          # Should non-application libraries be started as permanent?
          if app in @permanent_applications, do: :permanent, else: :temporary

        other_mode ->
          other_mode
      end

    {app, new_mode}
  end

  # Compute the transitive closure of the init apps
  defp all_init_applications(release, init_apps) do
    init_apps
    |> Enum.reduce(MapSet.new(), fn app, acc ->
      if is_atom(app) do
        release.applications[app][:applications]
        |> MapSet.new()
        |> MapSet.union(acc)
      else
        # skip non-apps
        acc
      end
    end)
  end

  defp app_compare({app1, _}, {app2, _}, init_apps) do
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
