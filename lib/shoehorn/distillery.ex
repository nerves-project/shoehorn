if Code.ensure_loaded?(Distillery.Releases.Plugin) do
  defmodule Shoehorn.Plugin do
    use Distillery.Releases.Plugin

    alias Shoehorn.Utils
    alias Distillery.Releases.{App, Release, Shell}
    alias Distillery.Releases.Utils, as: ReleaseUtils

    require Logger

    @excluded_applications [:distillery, :mix]

    # Distillery Behaviour
    def before_assembly(%Release{} = release, _opts) do
      {_, applications} = Enum.split_with(release.applications, &(&1 in @excluded_applications))
      %{release | applications: applications}
    end

    def after_assembly(%Release{} = release, _opts) do
      generate_boot_script(release)
      release
    end

    def before_package(%Release{} = release, _opts) do
      release
    end

    def after_package(%Release{} = release, _opts) do
      release
    end

    def after_cleanup(_args, _opts) do
      :noop
    end

    def generate_boot_script(app_release) do
      Application.load(:shoehorn)
      runtime_spec = Application.spec(:shoehorn)

      release = Release.new(:shoehorn, runtime_spec[:vsn])
      release = %{release | profile: app_release.profile}

      release_apps = Release.apps(release)
      release = %{release | :applications => release_apps}

      rel_dir =
        Path.join(["#{app_release.profile.output_dir}", "releases", "#{app_release.version}"])

      erts_vsn =
        case app_release.profile.include_erts do
          bool when is_boolean(bool) ->
            Distillery.Releases.Utils.erts_version()

          path ->
            {:ok, vsn} = Distillery.Releases.Utils.detect_erts_version(path)
            vsn
        end

      start_apps =
        Enum.filter(app_release.applications, fn %App{name: n} ->
          n in Utils.shoehorn_applications()
        end)

      {[shoehorn], start_apps} = Enum.split_with(start_apps, &(&1.name == :shoehorn))
      start_apps = [%{shoehorn | start_type: nil} | start_apps]

      load_apps =
        Enum.reject(app_release.applications, fn %App{name: n} ->
          n in Utils.shoehorn_applications()
        end)

      load_apps = Enum.map(load_apps, &{&1.name, '#{&1.vsn}', :none})

      start_apps =
        Enum.map(start_apps, fn %App{name: name, vsn: vsn, start_type: start_type} ->
          case start_type do
            nil ->
              {name, '#{vsn}'}

            t ->
              {name, '#{vsn}', t}
          end
        end)

      relfile = {:release, {'shoehorn', '0.1.0'}, {:erts, '#{erts_vsn}'}, start_apps ++ load_apps}
      path = Path.join(rel_dir, "shoehorn.rel")
      ReleaseUtils.write_term(path, relfile)

      erts_lib_dir =
        case release.profile.include_erts do
          false -> :code.lib_dir()
          true -> :code.lib_dir()
          p -> String.to_charlist(Path.expand(Path.join(p, "lib")))
        end

      options = [
        {:path, ['#{rel_dir}' | Release.get_code_paths(app_release)]},
        {:outdir, '#{rel_dir}'},
        {:variables, [{'ERTS_LIB_DIR', erts_lib_dir}]},
        :no_warn_sasl,
        :no_module_tests,
        :silent
      ]

      case :systools.make_script('shoehorn', options) do
        {:error, _, e} ->
          raise "Shoehorn failed to create bootscript with error: #{inspect(e)}"

        _ ->
          %Release{profile: %{output_dir: output_dir}, name: app} = app_release

          absolute_output_dir =
            Path.relative_to_cwd(output_dir)
            |> Path.absname()

          Shell.info("""
          Generated Shoehorn Boot Script
              Run using shoehorn:
                Interactive: #{absolute_output_dir}/bin/#{app} console_boot #{absolute_output_dir}/bin/shoehorn
          """)
      end

      File.cp(
        Path.join(rel_dir, "shoehorn.boot"),
        Path.join([app_release.profile.output_dir, "bin", "shoehorn.boot"])
      )
    catch
      _e ->
        Logger.error("\n#{Exception.format_stacktrace(System.stacktrace())}")

        exit({:shutdown, 1})
    end
  end
end
