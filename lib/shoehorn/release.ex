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

    sectioned_order =
      release
      |> init_app_dependencies_and_app(init_apps)
      |> Enum.with_index()
      |> Enum.flat_map(fn {applications, index} ->
        Enum.map(applications, fn app -> {app, index} end)
      end)
      |> Enum.uniq_by(&elem(&1, 0))
      |> Map.new()

    # Start with the start script since it applies the user overrides for the
    # start mode (the :applications option in the release).

    apps =
      release.boot_scripts[:start]
      |> Enum.map(&update_start_mode/1)
      |> Enum.sort(fn
        # IEx last
        {:iex, _}, {_, _} ->
          false

        # Order by sectioned order tailed by the rest
        {app_1, _}, {app_2, _} ->
          Map.get(sectioned_order, app_1, :other) <= Map.get(sectioned_order, app_2, :other)
      end)

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

  defp init_app_dependencies_and_app(release, init_apps) do
    Enum.flat_map(init_apps, fn
      app when is_atom(app) ->
        dependencies = release.applications |> Map.fetch!(app) |> Map.fetch!(:applications)
        {permanent_deps, deps} = Enum.split_with(dependencies, &(&1 in @permanent_applications))
        [permanent_deps, deps, [app]]

      {_, _, _} = mfa ->
        raise_mfa(mfa)
    end)
  end

  defp raise_mfa(mfa) do
    raise """
    #{inspect(mfa)} is no longer supported in the Shoehorn `:init` option.

    To fix, move this function call to an appropriate `Application.start/2`.
    Depending on what this is supposed to do, other ways may be possible too.

    Long story: While it looks like the `:init` list would be processed in
    order with the function calls in between `Application.start/1` calls, there
    really was no guarantee. Application dependencies and how applications are
    sorted in dependency lists take precedence over the `:init` list order.
    There's also a technical reason in that bare functions aren't allowed to be
    listed in application start lists for creating the release. While the
    latter could be fixed, not knowing when a function is called in relation to
    other application starts leads to confusing issues and it seems best to
    find another way when you want to do this.
    """
  end
end
