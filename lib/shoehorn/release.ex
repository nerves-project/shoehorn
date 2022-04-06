defmodule Shoehorn.Release do
  @moduledoc false

  alias Shoehorn.ReleaseError

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

  @doc """
  Build the shoehorn boot script
  """
  @spec init(Mix.Release.t()) :: Mix.Release.t()
  def init(%Mix.Release{} = release) do
    opts = options(release)

    init_apps = [:logger, :shoehorn, :sasl] ++ Access.get(opts, :init, [])
    last_apps = Access.get(opts, :last, [:iex])
    extra_deps = Access.get(opts, :extra_dependencies, [])

    # Validate arguments
    Enum.each(init_apps, &check_app(&1, release.applications))
    Enum.each(last_apps, &check_app(&1, release.applications))

    # Build dependency graph
    sorted_apps =
      :digraph.new([:private, :acyclic])
      |> add_release_apps(release.applications)
      |> add_extra_dependencies(extra_deps)
      |> add_init_dependencies(init_apps)
      |> add_last_dependencies(last_apps)
      |> alphabetize_dependencies()
      |> :digraph_utils.topsort()
      |> Enum.reverse()

    apps_with_modes = assign_modes_to_apps(release)

    start_apps =
      for app <- sorted_apps do
        {app, apps_with_modes[app]}
      end

    new_boot_scripts = Map.put(release.boot_scripts, :shoehorn, start_apps)

    %{release | boot_scripts: new_boot_scripts}
  end

  defp options(release) do
    config = Application.get_all_env(:shoehorn)
    options = release.options[:shoehorn] || []

    Keyword.merge(config, options)
  end

  defp assign_modes_to_apps(release) do
    # Mix release doesn't pass the user's application modes, but they can
    # be derived from the start script if it exists.
    case release.boot_scripts[:start] do
      nil ->
        release.applications
        |> Enum.map(fn {app, _info} -> {app, :permanent} end)
        |> Enum.map(&update_start_mode/1)

      app_modes ->
        Enum.map(app_modes, &update_start_mode/1)
    end
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

  defp add_release_apps(dep_graph, release_apps) do
    Enum.each(release_apps, fn {app, _info} -> :digraph.add_vertex(dep_graph, app) end)

    Enum.each(release_apps, fn {app, info} ->
      Enum.each(info[:applications], &:digraph.add_edge(dep_graph, app, &1, :release))
    end)

    dep_graph
  end

  defp add_extra_dependencies(dep_graph, extra_deps) do
    Enum.each(extra_deps, fn {app, deps} ->
      Enum.each(deps, &checked_add_edge(dep_graph, app, &1))
    end)

    dep_graph
  end

  defp checked_add_edge(graph, app, dep) do
    case :digraph.add_edge(graph, app, dep, :extra) do
      {:error, {:bad_vertex, v}} ->
        raise ReleaseError, "Unknown application #{inspect(v)}"

      {:error, {:bad_edge, [_, _]}} ->
        # Edge already exists, so this is ok
        :ok

      {:error, {:bad_edge, _path}} ->
        raise ReleaseError,
              "Cycle detected when adding the #{inspect(dep)} dependencies to #{inspect(app)}"

      _ ->
        :ok
    end
  end

  defp add_init_dependencies(dep_graph, init_apps) do
    # Make every non-init_app depend on the init_app unless there's a cycle
    all_apps = :digraph.vertices(dep_graph)
    non_init_apps = all_apps -- init_apps

    # Order deps in the init list
    order_dependencies(dep_graph, Enum.reverse(init_apps))

    # Try to make everything not in the init list depend on the init list
    # (cycles and dupes are automatically ignored)
    Enum.each(non_init_apps, fn non_init_app ->
      Enum.each(init_apps, &:digraph.add_edge(dep_graph, non_init_app, &1, :init))
    end)

    dep_graph
  end

  defp add_last_dependencies(dep_graph, last_apps) do
    # Make every last_app depend on all non-last_apps unless there's a cycle
    all_apps = :digraph.vertices(dep_graph)
    non_last_apps = all_apps -- last_apps

    Enum.each(last_apps, fn last_app ->
      Enum.each(non_last_apps, &:digraph.add_edge(dep_graph, last_app, &1, :last))
    end)

    dep_graph
  end

  defp alphabetize_dependencies(dep_graph) do
    # Add edges where possible to force dependencies to be sorted alphabetically
    sorted_apps = :digraph.vertices(dep_graph) |> Enum.sort(:desc)

    order_dependencies(dep_graph, sorted_apps)

    dep_graph
  end

  # defp inspect_graph(dep_graph) do
  #   Enum.each(:digraph.edges(dep_graph), fn e ->
  #     {_, v1, v2, label} = :digraph.edge(dep_graph, e)
  #     IO.puts("#{v1} -> #{v2} (#{label})")
  #   end)
  # end

  defp order_dependencies(_, []), do: :ok

  defp order_dependencies(dep_graph, [dep | rest]) do
    Enum.each(rest, &:digraph.add_edge(dep_graph, dep, &1, :alpha))
    order_dependencies(dep_graph, rest)
  end

  defp check_app(app, applications) when is_atom(app) do
    applications[app] != nil or raise ReleaseError, "#{app} is not a known OTP application"
  end

  defp check_app({_, _, _} = mfa, _applications) do
    raise ReleaseError, """
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

  defp check_app(other, _applications) do
    raise ReleaseError, """
    The Shoehorn `:init` option only supports atoms. #{inspect(other)}
    """
  end
end
