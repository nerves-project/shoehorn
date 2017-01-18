defmodule Bootloader.Plugin do
  use Mix.Releases.Plugin

  alias Bootloader.Utils
  alias Mix.Releases.{App, Release, Profile}
  alias Mix.Releases.Utils, as: ReleaseUtils

  def before_assembly(release), do: release

  def after_assembly(%Release{} = release) do
    generate_boot_script(release)
    release
  end

  def generate_boot_script(app_release) do

    Application.load(:bootloader)
    runtime_spec = Application.spec(:bootloader)

    release = Release.new(:bootloader, runtime_spec[:vsn])
    release = %{release | profile: app_release.profile}

    release_apps = ReleaseUtils.get_apps(release)
    release = %{release | :applications => release_apps}
    rel_dir = Path.join(["#{app_release.profile.output_dir}", "releases", "#{release.version}"])



    # This needs to change...
    erts_vsn =
      case System.get_env("ERL_LIB_DIR") do
        nil -> Mix.Releases.Utils.erts_version()
        path ->
          {:ok, vsn} = Mix.Releases.Utils.detect_erts_version(path)
          vsn
      end
    # apps_path = Keyword.get(Mix.Project.config, :apps_path)
    #apps_paths = Path.wildcard("#{apps_path}/*")

    start_apps = Enum.filter(app_release.applications, fn %App{name: n} ->
                               n in Utils.bootloader_applications end)
    load_apps = Enum.reject(app_release.applications,  fn %App{name: n} ->
                               n in Utils.bootloader_applications end)
    load_apps =
      #[]
      Enum.map(load_apps, & {&1.name, '#{&1.vsn}', :none})
    start_apps =
      Enum.map(start_apps, fn %App{name: name, vsn: vsn, start_type: start_type} ->
        case start_type do
          nil ->
            {name, '#{vsn}'}
          t ->
            {name, '#{vsn}', t}
        end
      end)
    relfile = {:release,
                    {'bootloader', '0.1.0'},
                    {:erts, '#{erts_vsn}'},
                    start_apps ++ load_apps}
    path = Path.join(rel_dir, "bootloader.rel")
    ReleaseUtils.write_term(path, relfile)

    erts_lib_dir =
      case release.profile.include_erts do
        false -> :code.lib_dir()
        true  -> :code.lib_dir()
        p     -> String.to_charlist(Path.expand(Path.join(p, "lib")))
      end

    options = [{:path, ['#{rel_dir}' | Release.get_code_paths(app_release)]},
               {:outdir, '#{rel_dir}'},
               {:variables, [{'ERTS_LIB_DIR', erts_lib_dir}]},
               :no_warn_sasl,
               :no_module_tests,
               :silent]

    :systools.make_script('bootloader', options)
    |> IO.inspect
    File.cp(Path.join(rel_dir, "bootloader.boot"),
                            Path.join([app_release.profile.output_dir, "bin", "bootloader.boot"]))
  end
end
