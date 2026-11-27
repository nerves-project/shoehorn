# SPDX-FileCopyrightText: 2026 Lars Wikman
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Shoehorn.InstallTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  defp mix_exs(opts) do
    deps = Keyword.get(opts, :deps, [])
    release = Keyword.get(opts, :release)

    """
    defmodule Test.MixProject do
      use Mix.Project

      @app :test

      def project do
        [
          app: @app,
          version: "0.1.0",
          elixir: "~> 1.17",
          deps: deps()#{if release, do: ",\n      releases: [{@app, release()}]"}
        ]
      end

      defp deps do
        [
          #{Enum.join(deps, ",\n      ")}
        ]
      end
    #{if release, do: "\n  def release do\n    [\n      overwrite: true,\n      #{release}\n    ]\n  end\n"}
    end
    """
  end

  @nerves1 ~s|{:nerves, "~> 1.10", runtime: false}|
  @nerves2 ~s|{:nerves, "~> 2.0", runtime: false}|
  @shoehorn ~s|{:shoehorn, "~> 0.9.1"}|
  @nerves_runtime ~s|{:nerves_runtime, "~> 0.13.0"}|
  @nerves_pack ~s|{:nerves_pack, "~> 0.7.1", targets: [:rpi4]}|

  @v1_steps "steps: [&Nerves.Release.init/1, :assemble]"
  @v2_steps "steps: [&Nerves.init_release/1, :assemble]"

  defp nerves1_project(files \\ %{}, deps \\ [@nerves_runtime, @nerves_pack]) do
    project(files, deps: [@nerves1, @shoehorn | deps], release: @v1_steps)
  end

  defp nerves2_project(files \\ %{}, deps \\ [@nerves_runtime, @nerves_pack]) do
    project(files, deps: [@nerves2, @shoehorn | deps], release: @v2_steps)
  end

  defp project(files, mix_exs_opts) do
    test_project(
      files:
        Map.merge(
          %{"mix.exs" => mix_exs(mix_exs_opts), "config/target.exs" => "import Config\n"},
          files
        )
    )
  end

  defp plain_project(files \\ %{}, mix_exs_opts \\ [deps: [@shoehorn]]) do
    test_project(files: Map.merge(%{"mix.exs" => mix_exs(mix_exs_opts)}, files))
  end

  defp install(igniter, argv \\ []) do
    Igniter.compose_task(igniter, "shoehorn.install", argv)
  end

  defp notices(igniter), do: Enum.join(igniter.notices, "\n")

  describe "Nerves 1.x project" do
    test "writes the template's init list to config/target.exs" do
      igniter =
        nerves1_project()
        |> install()
        |> assert_has_patch("config/target.exs", """
        + |config :shoehorn, init: [:nerves_runtime, :nerves_pack]
        """)
        |> assert_unchanged("mix.exs")

      # &Nerves.Release.init/1 calls Shoehorn, so there's nothing to tell.
      assert igniter.notices == []
      refute Igniter.exists?(igniter, "config/config.exs")
    end

    test "only lists the applications that are dependencies" do
      nerves1_project(%{}, [@nerves_runtime])
      |> install()
      |> assert_has_patch("config/target.exs", """
      + |config :shoehorn, init: [:nerves_runtime]
      """)

      nerves1_project(%{}, [@nerves_pack])
      |> install()
      |> assert_has_patch("config/target.exs", """
      + |config :shoehorn, init: [:nerves_pack]
      """)
    end

    test "writes nothing when there's nothing to list" do
      igniter =
        nerves1_project(%{}, [])
        |> install()
        |> assert_unchanged("config/target.exs")

      assert igniter.notices == []
    end

    test "is detected from the nerves requirement when there's no release config" do
      igniter =
        project(%{}, deps: [@nerves1, @shoehorn, @nerves_runtime])
        |> install()
        |> assert_has_patch("config/target.exs", """
        + |config :shoehorn, init: [:nerves_runtime]
        """)

      assert igniter.notices == []
    end

    test "is idempotent" do
      nerves1_project()
      |> install()
      |> apply_igniter!()
      |> install()
      |> assert_unchanged()
    end

    test "--shoehorn-release-step leaves the release alone" do
      nerves1_project()
      |> install(["--shoehorn-release-step"])
      |> assert_unchanged("mix.exs")
    end
  end

  describe "existing configuration" do
    test "other shoehorn options are preserved" do
      nerves1_project(%{
        "config/target.exs" => """
        import Config

        config :shoehorn, handler: MyApp.ShoehornHandler, shutdown_timer: 50_000
        """
      })
      |> install()
      |> assert_has_patch("config/target.exs", """
      - |config :shoehorn, handler: MyApp.ShoehornHandler, shutdown_timer: 50_000
      + |config :shoehorn,
      + |  handler: MyApp.ShoehornHandler,
      + |  shutdown_timer: 50_000,
      + |  init: [:nerves_runtime, :nerves_pack]
      """)
    end

    test "a complete init list is left alone" do
      nerves1_project(%{
        "config/target.exs" => """
        import Config

        config :shoehorn, init: [:my_app, :nerves_pack, :nerves_runtime]
        """
      })
      |> install()
      |> assert_unchanged()
    end

    # This is what `mix nerves_runtime.install` leaves behind when it runs
    # before this installer.
    test "composes with nerves_runtime.install having run first" do
      nerves1_project(%{
        "config/target.exs" => """
        import Config

        config :shoehorn, init: [:nerves_runtime]
        """
      })
      |> install()
      |> assert_has_patch("config/target.exs", """
      - |config :shoehorn, init: [:nerves_runtime]
      + |config :shoehorn, init: [:nerves_runtime, :nerves_pack]
      """)
      |> apply_igniter!()
      |> install()
      |> assert_unchanged()
    end

    # `mix nerves_runtime.install` prepends `:nerves_runtime` unless it's in
    # the list, so writing it first here gives the same result when this
    # installer runs first.
    test "puts nerves_runtime where nerves_runtime.install would" do
      nerves1_project(%{
        "config/target.exs" => """
        import Config

        config :shoehorn, init: [:foo]
        """
      })
      |> install()
      |> assert_has_patch("config/target.exs", """
      - |config :shoehorn, init: [:foo]
      + |config :shoehorn, init: [:nerves_runtime, :foo, :nerves_pack]
      """)

      nerves1_project(%{
        "config/target.exs" => """
        import Config

        config :shoehorn, init: [:logger_backends, :foo]
        """
      })
      |> install()
      |> assert_has_patch("config/target.exs", """
      - |config :shoehorn, init: [:logger_backends, :foo]
      + |config :shoehorn, init: [:logger_backends, :nerves_runtime, :foo, :nerves_pack]
      """)
    end

    test "an init list in config/config.exs is updated in place" do
      nerves1_project(%{
        "config/config.exs" => """
        import Config

        config :shoehorn, init: [:nerves_runtime]
        """
      })
      |> install()
      |> assert_has_patch("config/config.exs", """
      - |config :shoehorn, init: [:nerves_runtime]
      + |config :shoehorn, init: [:nerves_runtime, :nerves_pack]
      """)
      |> assert_unchanged("config/target.exs")
    end

    test "an init list that isn't a literal list is left alone" do
      nerves1_project(%{
        "config/target.exs" => """
        import Config

        init_apps = [:nerves_runtime]
        config :shoehorn, init: init_apps
        """
      })
      |> install(["--shoehorn-init", "my_app"])
      |> assert_unchanged()
    end
  end

  describe "--shoehorn-init" do
    test "adds applications after the defaults" do
      nerves1_project()
      |> install(["--shoehorn-init", "my_early_app,other_app", "--shoehorn-init", ":third_app"])
      |> assert_has_patch("config/target.exs", """
      + |config :shoehorn, init: [:nerves_runtime, :nerves_pack, :my_early_app, :other_app, :third_app]
      """)
    end

    test "doesn't duplicate applications" do
      nerves1_project(%{
        "config/target.exs" => """
        import Config

        config :shoehorn, init: [:my_early_app, :nerves_runtime]
        """
      })
      |> install(["--shoehorn-init", "nerves_runtime,my_early_app,other_app,other_app"])
      |> assert_has_patch("config/target.exs", """
      - |config :shoehorn, init: [:my_early_app, :nerves_runtime]
      + |config :shoehorn, init: [:my_early_app, :nerves_runtime, :nerves_pack, :other_app]
      """)
    end

    test "is idempotent" do
      nerves1_project()
      |> install(["--shoehorn-init", "my_early_app"])
      |> apply_igniter!()
      |> install(["--shoehorn-init", "my_early_app"])
      |> assert_unchanged()
    end

    test "rejects things that aren't application names" do
      igniter =
        nerves1_project()
        |> install(["--shoehorn-init", "MyApp.Thing"])
        |> assert_unchanged()

      assert Enum.join(igniter.issues, "\n") =~ ~s|--shoehorn-init expects OTP application names|
      assert Enum.join(igniter.issues, "\n") =~ ~s|"MyApp.Thing"|
    end
  end

  describe "Nerves 2 project" do
    test "writes the config and explains what Shoehorn does on Nerves 2" do
      igniter =
        nerves2_project()
        |> install()
        |> assert_has_patch("config/target.exs", """
        + |config :shoehorn, init: [:nerves_runtime, :nerves_pack]
        """)
        |> assert_unchanged("mix.exs")

      assert [notice] = igniter.notices
      assert notice =~ "this is a Nerves 2 project. As configured, Shoehorn does nothing"
      assert notice =~ "config :nerves, application_sort: [init: [...]]"
      assert notice =~ "No `shoehorn.boot` release boot script is generated"
      assert notice =~ "steps: [&Nerves.init_release/1, &Shoehorn.Release.init/1, :assemble]"
      assert notice =~ "--boot shoehorn"
    end

    test "leaves the application_sort config alone" do
      nerves2_project(%{
        "config/target.exs" => """
        import Config

        config :nerves, application_sort: [init: [:nerves_runtime]]
        """
      })
      |> install()
      |> assert_has_patch("config/target.exs", """
      + |config :shoehorn, init: [:nerves_runtime, :nerves_pack]
        |config :nerves, application_sort: [init: [:nerves_runtime]]
      """)
    end

    test "is detected from the application_sort config" do
      igniter =
        project(
          %{
            "config/target.exs" => """
            import Config

            config :nerves, application_sort: [init: [:nerves_runtime]]
            """
          },
          deps: [@shoehorn]
        )
        |> install()

      assert notices(igniter) =~ "this is a Nerves 2 project"
    end

    test "is detected from the nerves requirement" do
      for nerves <- [@nerves2, ~s|{:nerves, "~> 2.0.0-pre.10", runtime: false}|] do
        igniter = project(%{}, deps: [nerves, @shoehorn]) |> install()

        assert notices(igniter) =~ "this is a Nerves 2 project"
      end
    end

    test "is assumed for nerves path dependencies" do
      igniter =
        project(%{}, deps: [~s|{:nerves, path: "../nerves", runtime: false}|, @shoehorn])
        |> install()

      assert notices(igniter) =~ "this is a Nerves 2 project"
    end

    test "that still calls Nerves.Release.init/1 needs nothing" do
      igniter =
        project(%{}, deps: [@nerves2, @shoehorn, @nerves_runtime], release: @v1_steps)
        |> install(["--shoehorn-release-step"])
        |> assert_unchanged("mix.exs")

      assert igniter.notices == []
    end

    test "--shoehorn-release-step adds the step after Nerves.init_release/1" do
      igniter =
        nerves2_project()
        |> install(["--shoehorn-release-step"])
        |> assert_has_patch("mix.exs", """
        - |      steps: [&Nerves.init_release/1, :assemble]
        + |      steps: [&Nerves.init_release/1, &Shoehorn.Release.init/1, :assemble]
        """)

      assert [notice] = igniter.notices
      assert notice =~ "calls &Shoehorn.Release.init/1"
      assert notice =~ "`config :nerves, application_sort: [...]`\n  only applies to `start.boot`"
      assert notice =~ "--boot shoehorn"
      refute notice =~ "Shoehorn does nothing"
    end

    test "--shoehorn-release-step is idempotent" do
      nerves2_project()
      |> install(["--shoehorn-release-step"])
      |> apply_igniter!()
      |> install(["--shoehorn-release-step"])
      |> assert_unchanged()
    end

    test "is idempotent" do
      nerves2_project()
      |> install()
      |> apply_igniter!()
      |> install()
      |> assert_unchanged()
    end
  end

  describe "plain project" do
    test "writes no config and explains the release steps" do
      igniter =
        plain_project()
        |> install()
        |> assert_unchanged()

      assert notices(igniter) =~ "steps: [&Shoehorn.Release.init/1, :assemble]"
      assert notices(igniter) =~ "RELEASE_BOOT_SCRIPT=shoehorn"
      refute notices(igniter) =~ "Nerves 2"
    end

    test "falls back to config/config.exs with a notice" do
      igniter =
        plain_project(%{}, deps: [@shoehorn, @nerves_runtime])
        |> install(["--shoehorn-init", "my_app"])
        |> assert_creates("config/config.exs", """
        import Config
        config :shoehorn, init: [:nerves_runtime, :my_app]
        """)

      assert notices(igniter) =~ "no config/target.exs found"
    end

    test "--shoehorn-release-step adds the step to existing steps" do
      igniter =
        plain_project(%{},
          deps: [@shoehorn],
          release: "steps: [:assemble, :tar]"
        )
        |> install(["--shoehorn-release-step"])
        |> assert_has_patch("mix.exs", """
        - |      steps: [:assemble, :tar]
        + |      steps: [&Shoehorn.Release.init/1, :assemble, :tar]
        """)

      refute notices(igniter) =~ "add Shoehorn to the Mix release steps"
      assert notices(igniter) =~ "RELEASE_BOOT_SCRIPT=shoehorn"
    end

    test "--shoehorn-release-step doesn't invent a release" do
      igniter =
        plain_project()
        |> install(["--shoehorn-release-step"])
        |> assert_unchanged()

      assert notices(igniter) =~ "add Shoehorn to the Mix release steps"
    end

    test "--shoehorn-release-step leaves steps with Shoehorn alone" do
      plain_project(%{},
        deps: [@shoehorn],
        release: "steps: [&Shoehorn.Release.init/1, :assemble]"
      )
      |> install(["--shoehorn-release-step"])
      |> assert_unchanged()
    end

    test "is idempotent" do
      plain_project(%{}, deps: [@shoehorn, @nerves_runtime])
      |> install()
      |> apply_igniter!()
      |> install()
      |> assert_unchanged()
    end
  end
end
