# SPDX-FileCopyrightText: 2026 Lars Wikman
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Shoehorn.Install.Docs do
  @moduledoc false

  @spec short_doc() :: String.t()
  def short_doc() do
    "Installs shoehorn in your project."
  end

  @spec example() :: String.t()
  def example() do
    "mix igniter.install shoehorn"
  end

  @spec long_doc() :: String.t()
  def long_doc() do
    """
    #{short_doc()}

    Nerves 2 projects don't need Shoehorn to order OTP application starts or
    to keep the Erlang VM running when an OTP application exits. Nerves does
    both itself. Install Shoehorn if you have a Nerves 1.x project or if you
    want a `Shoehorn.Handler` to be called when OTP applications start and
    exit.

    ## Example

    ```bash
    #{example()}
    ```

    ## What it does

    * Configures the list of OTP applications that Shoehorn starts first:

      ```elixir
      config :shoehorn, init: [:nerves_runtime, :nerves_pack]
      ```

      Only the ones of `:nerves_runtime` and `:nerves_pack` that are
      dependencies of the project are listed. The configuration is written to
      `config/target.exs` when that file exists and to `config/config.exs`
      otherwise. If the project already has an `:init` list, the missing
      applications are added to it and everything else is kept as is. Nothing
      is written when there are no applications to list.
    * Tells you what's left to do to have the release use Shoehorn. This
      depends on whether it's a Nerves 1.x, Nerves 2 or non-Nerves project.

    The Mix release configuration in `mix.exs` is only modified when
    `--shoehorn-release-step` is passed.

    ## Options

    * `--shoehorn-init` - An additional OTP application to add to Shoehorn's
      `:init` list. It can be passed more than once and it accepts a comma
      separated list: `--shoehorn-init my_early_app,my_other_app`
    * `--shoehorn-release-step` - Add `&Shoehorn.Release.init/1` before
      `:assemble` to the Mix release `:steps` in `mix.exs`. Projects that call
      `&Nerves.Release.init/1` (Nerves 1.x) are left alone since that already
      calls Shoehorn. Defaults to off.
    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.Shoehorn.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"

    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    alias Igniter.Code.Common
    alias Igniter.Project.Config
    alias Igniter.Project.Deps
    alias Sourceror.Zipper

    # Keep this in sync with the `config :shoehorn` line in nerves_bootstrap's
    # 1.x templates/new/config/target.exs
    @template_init_apps [:nerves_runtime, :nerves_pack]

    @shoehorn_step "&Shoehorn.Release.init/1"

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :shoehorn,
        example: __MODULE__.Docs.example(),
        schema: [shoehorn_init: :csv, shoehorn_release_step: :boolean],
        defaults: [shoehorn_release_step: false]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      case extra_init_apps(igniter) do
        {:ok, extra_apps} ->
          kind = project_kind(igniter)

          igniter
          |> configure_init(extra_apps)
          |> maybe_add_release_step(kind)
          |> add_release_notice(kind)

        {:error, invalid} ->
          Igniter.add_issue(igniter, """
          shoehorn: --shoehorn-init expects OTP application names like `my_app`. Got: #{inspect(invalid)}
          """)
      end
    end

    # -- Options ---------------------------------------------------------------

    # Application names are kept as strings and turned into code so that
    # arbitrary user input is never converted to atoms.
    defp extra_init_apps(igniter) do
      apps =
        igniter.args.options[:shoehorn_init]
        |> List.wrap()
        |> Enum.map(&(&1 |> String.trim() |> String.trim_leading(":")))
        |> Enum.reject(&(&1 == ""))
        |> Enum.uniq()

      case Enum.reject(apps, &(&1 =~ ~r/^[a-z][a-z0-9_]*$/)) do
        [] -> {:ok, apps}
        invalid -> {:error, invalid}
      end
    end

    # -- config :shoehorn, init: [...] -----------------------------------------

    defp configure_init(igniter, extra_apps) do
      template_apps =
        @template_init_apps
        |> Enum.filter(&Deps.has_dep?(igniter, &1))
        |> Enum.map(&Atom.to_string/1)

      apps = Enum.uniq(template_apps ++ extra_apps)
      existing = configured_in(igniter, :shoehorn, [:init])

      cond do
        apps == [] ->
          igniter

        existing ->
          configure_init_in(igniter, existing, apps)

        Igniter.exists?(igniter, "config/target.exs") ->
          configure_init_in(igniter, "target.exs", apps)

        true ->
          igniter
          |> configure_init_in("config.exs", apps)
          |> Igniter.add_notice("""
          shoehorn: no config/target.exs found, so the shoehorn configuration was
          written to config/config.exs. The defaults are intended for Nerves
          projects where they normally live in config/target.exs.
          """)
      end
    end

    defp configure_init_in(igniter, file, apps) do
      new_list = Sourceror.parse_string!("[" <> Enum.map_join(apps, ", ", &":#{&1}") <> "]")

      Config.configure(igniter, file, :shoehorn, [:init], {:code, new_list},
        updater: &{:ok, add_to_init_list(&1, apps)}
      )
    end

    # Returns the first of config/target.exs and config/config.exs that
    # configures the key or nil.
    defp configured_in(igniter, app, path) do
      Enum.find(["target.exs", "config.exs"], fn file ->
        Igniter.exists?(igniter, Path.join("config", file)) and
          Config.configures_key?(igniter, file, app, path)
      end)
    end

    # Adds the missing applications to an existing list. Everything that's
    # already there keeps its position. Anything that isn't a literal list is
    # left alone.
    defp add_to_init_list(zipper, apps) do
      case Common.within(zipper, &add_to_literal_init_list(&1, apps)) do
        {:ok, zipper} -> zipper
        :error -> zipper
      end
    end

    defp add_to_literal_init_list(list, apps) do
      if Igniter.Code.List.list?(list) do
        Enum.reduce_while(apps, {:ok, list}, &add_app_while/2)
      else
        :error
      end
    end

    defp add_app_while(app, {:ok, list}) do
      case add_app(list, app) do
        {:ok, list} -> {:cont, {:ok, list}}
        :error -> {:halt, :error}
      end
    end

    defp add_app(list, app) do
      cond do
        Igniter.Code.List.find_list_item_index(list, &app?(&1, app)) ->
          {:ok, list}

        app == "nerves_runtime" ->
          # This is where `mix nerves_runtime.install` puts it so that the
          # result is the same no matter which installer runs first.
          insert_nerves_runtime(list)

        true ->
          Igniter.Code.List.append_to_list(list, app_code(app))
      end
    end

    defp insert_nerves_runtime(list) do
      case Igniter.Code.List.move_to_list_item(list, &app?(&1, "logger_backends")) do
        {:ok, item} ->
          {:ok, item |> Zipper.insert_right(app_code("nerves_runtime")) |> Zipper.up()}

        :error ->
          Igniter.Code.List.prepend_to_list(list, app_code("nerves_runtime"))
      end
    end

    defp app_code(app), do: Sourceror.parse_string!(":" <> app)

    defp app?(zipper, app) do
      case zipper.node do
        {:__block__, _, [atom]} when is_atom(atom) -> Atom.to_string(atom) == app
        atom when is_atom(atom) -> Atom.to_string(atom) == app
        _ -> false
      end
    end

    # -- Project detection -----------------------------------------------------

    # Returns how the project's release is built:
    #
    # * `:nerves_v1` - The release calls `&Nerves.Release.init/1`. That calls
    #   `Shoehorn.Release.init/1` when Shoehorn is a dependency, so there's
    #   nothing to do. This is every Nerves 1.x project. Nerves 2 still supports
    #   it as a deprecated entry point.
    # * `:nerves_v2` - The release calls `&Nerves.init_release/1`, which doesn't
    #   know about Shoehorn.
    # * `:plain` - Not a Nerves project
    defp project_kind(igniter) do
      mix_exs = mix_exs_content(igniter)

      cond do
        mix_exs =~ "Nerves.Release.init" -> :nerves_v1
        mix_exs =~ "Nerves.init_release" -> :nerves_v2
        configured_in(igniter, :nerves, [:application_sort]) -> :nerves_v2
        true -> kind_from_nerves_dep(igniter)
      end
    end

    defp kind_from_nerves_dep(igniter) do
      with {:ok, code} when is_binary(code) <- Deps.get_dep(igniter, :nerves),
           {:ok, quoted} <- Code.string_to_quoted(code) do
        kind_from_requirement(nerves_requirement(quoted))
      else
        _ -> :plain
      end
    end

    defp kind_from_requirement({:ok, requirement}) do
      if Version.match?("2.0.0", requirement), do: :nerves_v2, else: :nerves_v1
    end

    # Path and git dependencies. Nerves 2 is what's current.
    defp kind_from_requirement(:error), do: :nerves_v2

    defp nerves_requirement({:nerves, requirement}), do: parse_requirement(requirement)

    defp nerves_requirement({:{}, _, [:nerves, requirement | _]}),
      do: parse_requirement(requirement)

    defp nerves_requirement(_), do: :error

    defp parse_requirement(requirement) when is_binary(requirement),
      do: Version.parse_requirement(requirement)

    defp parse_requirement(_), do: :error

    defp mix_exs_content(igniter) do
      igniter = Igniter.include_existing_file(igniter, "mix.exs")

      case Rewrite.source(igniter.rewrite, "mix.exs") do
        {:ok, source} -> Rewrite.Source.get(source, :content)
        _ -> ""
      end
    end

    defp shoehorn_step?(igniter), do: mix_exs_content(igniter) =~ "Shoehorn.Release.init"

    # -- Release steps ---------------------------------------------------------

    defp maybe_add_release_step(igniter, kind) do
      if igniter.args.options[:shoehorn_release_step] and kind != :nerves_v1 and
           release_step_missing?(igniter) do
        Igniter.update_elixir_file(igniter, "mix.exs", &{:ok, add_release_step(&1)})
      else
        igniter
      end
    end

    # Checked up front so that mix.exs isn't touched (and reformatted) when
    # there's nothing to add.
    defp release_step_missing?(igniter) do
      igniter = Igniter.include_existing_file(igniter, "mix.exs")

      case Rewrite.source(igniter.rewrite, "mix.exs") do
        {:ok, source} ->
          zipper = source |> Rewrite.Source.get(:quoted) |> Zipper.zip()
          Zipper.topmost_root(add_release_step(zipper)) != Zipper.topmost_root(zipper)

        _ ->
          false
      end
    end

    # Adds the Shoehorn step right before `:assemble` in every literal
    # `steps: [..., :assemble, ...]` list that doesn't already have it. On
    # Nerves 2, this puts it after `&Nerves.init_release/1`.
    defp add_release_step(zipper) do
      Zipper.traverse(zipper, fn zipper ->
        case zipper.node do
          {{:__block__, key_meta, [:steps]}, {:__block__, list_meta, [steps]}}
          when is_list(steps) ->
            new_steps = insert_before_assemble(steps)
            new_node = {{:__block__, key_meta, [:steps]}, {:__block__, list_meta, [new_steps]}}
            Zipper.replace(zipper, new_node)

          _ ->
            zipper
        end
      end)
    end

    defp insert_before_assemble(steps) do
      if Enum.any?(steps, &(Sourceror.to_string(&1) =~ "Shoehorn.Release.init")) do
        steps
      else
        Enum.flat_map(steps, fn
          {:__block__, _, [:assemble]} = step -> [Sourceror.parse_string!(@shoehorn_step), step]
          step -> [step]
        end)
      end
    end

    # -- Notices ---------------------------------------------------------------

    defp add_release_notice(igniter, :nerves_v1), do: igniter

    defp add_release_notice(igniter, :nerves_v2) do
      if shoehorn_step?(igniter) do
        Igniter.add_notice(igniter, """
        shoehorn: this is a Nerves 2 project that calls #{@shoehorn_step}
        from its Mix release steps in mix.exs, so a `shoehorn.boot` release boot
        script is generated in addition to the `start.boot` one that Nerves makes.

        * `shoehorn.boot` orders OTP applications using `config :shoehorn` (`:init`,
          `:last`, `:extra_dependencies`). `config :nerves, application_sort: [...]`
          only applies to `start.boot`.
        * `Shoehorn.Handler` callbacks are only called when the device boots
          `shoehorn.boot`. This requires `--boot shoehorn` in erlinit.config. Nerves
          keeps that option if the Nerves system sets it and `:shoehorn` is a
          dependency. If your system doesn't set it, add
          `config :nerves, :erlinit, boot: "shoehorn"` to config/target.exs. Check
          `/etc/erlinit.config` on the device.
        """)
      else
        Igniter.add_notice(igniter, """
        shoehorn: this is a Nerves 2 project. As configured, Shoehorn does nothing
        in it.

        Nerves 2 doesn't call Shoehorn when building the release:

        * OTP application start order comes from
          `config :nerves, application_sort: [init: [...]]`, not from
          `config :shoehorn, init: [...]`.
        * Nerves already starts most OTP applications as `:temporary` so that the
          Erlang VM keeps running when one of them exits.
        * No `shoehorn.boot` release boot script is generated, so the device boots
          `start.boot` and Shoehorn doesn't call your `Shoehorn.Handler`.

        What Shoehorn still provides is the `Shoehorn.Handler` behaviour for
        reacting to OTP applications starting and exiting. To use it, add
        Shoehorn to the release steps in mix.exs (or rerun this installer with
        `--shoehorn-release-step`):

            steps: [&Nerves.init_release/1, #{@shoehorn_step}, :assemble]

        `shoehorn.boot` is then generated and ordered by `config :shoehorn`. The
        device also has to boot it. This requires `--boot shoehorn` in
        erlinit.config. Nerves keeps that option if the Nerves system sets it and
        `:shoehorn` is a dependency. If your system doesn't set it, add
        `config :nerves, :erlinit, boot: "shoehorn"` to config/target.exs.

        If you only wanted application ordering, remove `:shoehorn` and see
        "Updating from v1.x to v2.0" at https://nerves.hexdocs.pm/updating-projects.html
        """)
      end
    end

    defp add_release_notice(igniter, :plain) do
      if shoehorn_step?(igniter) do
        add_boot_script_notice(igniter)
      else
        igniter
        |> Igniter.add_notice("""
        shoehorn: add Shoehorn to the Mix release steps in your mix.exs (or rerun
        this installer with `--shoehorn-release-step` if you already have a
        `:steps` list):

            def project do
              [
                ...
                releases: [
                  my_app: [
                    steps: [#{@shoehorn_step}, :assemble]
                  ]
                ]
              ]
            end
        """)
        |> add_boot_script_notice()
      end
    end

    defp add_boot_script_notice(igniter) do
      Igniter.add_notice(igniter, """
      shoehorn: Shoehorn is only active when the release is started with the
      `shoehorn` boot script. For example:

          RELEASE_BOOT_SCRIPT=shoehorn _build/dev/rel/my_app/bin/my_app start_iex

      See https://shoehorn.hexdocs.pm/readme.html
      """)
    end
  end
else
  defmodule Mix.Tasks.Shoehorn.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'shoehorn.install' requires igniter. Please install igniter and try again.

      For more information, see: https://igniter.hexdocs.pm/readme.html#installation
      """)

      exit({:shutdown, 1})
    end
  end
end
