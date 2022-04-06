defmodule Shoehorn.ReleaseTest do
  use ExUnit.Case, async: true

  alias Shoehorn.Release
  alias Shoehorn.ReleaseError

  @example_release %Mix.Release{
    name: :my_project,
    version: "0.0.1",
    path: "",
    version_path: "",
    applications: %{
      compiler: [
        applications: [:kernel, :stdlib],
        runtime_dependencies: ['stdlib-3.13', 'kernel-7.0', 'erts-11.0', 'crypto-3.6']
      ],
      crash_app: [
        applications: [:kernel, :stdlib, :elixir, :logger],
        mod: {CrashApp.Application, []}
      ],
      crypto: [
        applications: [:kernel, :stdlib],
        runtime_dependencies: ['erts-9.0', 'stdlib-3.4', 'kernel-5.3']
      ],
      elixir: [
        applications: [:kernel, :stdlib, :compiler]
      ],
      iex: [
        applications: [:kernel, :stdlib, :elixir],
        mod: {IEx.App, []}
      ],
      kernel: [
        applications: [],
        mod: {:kernel, []}
      ],
      load_only_app: [
        applications: [:kernel, :stdlib, :elixir, :logger],
        mod: {LoadOnlyApp.Application, []}
      ],
      logger: [
        applications: [:kernel, :stdlib, :elixir],
        mod: {Logger.App, []}
      ],
      my_project: [
        applications: [
          :kernel,
          :stdlib,
          :elixir,
          :logger,
          :crash_app,
          :optional_app,
          :pure_library,
          :shoehorn,
          :some_app,
          :system_init
        ],
        mod: {MyProject.Application, []}
      ],
      optional_app: [
        applications: [:kernel, :stdlib, :elixir, :logger],
        mod: {OptionalApp.Application, []}
      ],
      pure_library: [
        applications: [:kernel, :stdlib, :elixir, :logger],
        registered: []
      ],
      sasl: [
        applications: [:kernel, :stdlib],
        mod: {:sasl, []}
      ],
      shoehorn: [
        applications: [:kernel, :stdlib, :elixir, :crypto, :logger],
        mod: {Shoehorn.Application, []}
      ],
      some_app: [
        applications: [:kernel, :stdlib, :elixir, :logger],
        mod: {SomeApp.Application, []}
      ],
      stdlib: [
        applications: [:kernel]
      ],
      system_init: [
        applications: [:kernel, :stdlib, :elixir, :logger],
        mod: {SystemInit.Application, []}
      ]
    },
    boot_scripts: %{
      start: [
        kernel: :permanent,
        stdlib: :permanent,
        elixir: :permanent,
        sasl: :permanent,
        load_only_app: :load,
        my_project: :permanent,
        iex: :none,
        compiler: :permanent,
        crash_app: :permanent,
        crypto: :permanent,
        logger: :permanent,
        optional_app: :permanent,
        pure_library: :permanent,
        shoehorn: :permanent,
        some_app: :permanent,
        system_init: :permanent
      ]
    },
    erts_version: '',
    erts_source: nil,
    config_providers: [],
    options: [],
    overlays: [],
    steps: [:assemble]
  }

  test "Generates example app list in order" do
    result = Release.init(@example_release)
    shoehorn_release = result.boot_scripts[:shoehorn]

    assert shoehorn_release == [
             kernel: :permanent,
             stdlib: :permanent,
             compiler: :permanent,
             elixir: :permanent,
             logger: :permanent,
             crypto: :permanent,
             shoehorn: :permanent,
             sasl: :permanent,
             crash_app: :temporary,
             load_only_app: :load,
             optional_app: :temporary,
             pure_library: :temporary,
             some_app: :temporary,
             system_init: :temporary,
             my_project: :temporary,
             iex: :none
           ]
  end

  test "release doesn't include start list" do
    release = @example_release |> Map.put(:boot_scripts, %{})
    result = Release.init(release)
    shoehorn_release = result.boot_scripts[:shoehorn]

    # The load_only_app and iex applications are technically wrong, but the information
    # was lost and shoehorn did its best
    assert shoehorn_release == [
             kernel: :permanent,
             stdlib: :permanent,
             compiler: :permanent,
             elixir: :permanent,
             logger: :permanent,
             crypto: :permanent,
             shoehorn: :permanent,
             sasl: :permanent,
             crash_app: :temporary,
             load_only_app: :temporary,
             optional_app: :temporary,
             pure_library: :temporary,
             some_app: :temporary,
             system_init: :temporary,
             my_project: :temporary,
             iex: :permanent
           ]
  end

  test "init apps move earlier" do
    release = @example_release |> Map.put(:options, shoehorn: [init: [:system_init]])
    result = Release.init(release)
    shoehorn_release = result.boot_scripts[:shoehorn]

    # system_init gets started earlier now
    assert shoehorn_release == [
             kernel: :permanent,
             stdlib: :permanent,
             compiler: :permanent,
             elixir: :permanent,
             logger: :permanent,
             crypto: :permanent,
             shoehorn: :permanent,
             sasl: :permanent,
             system_init: :temporary,
             crash_app: :temporary,
             load_only_app: :load,
             optional_app: :temporary,
             pure_library: :temporary,
             some_app: :temporary,
             my_project: :temporary,
             iex: :none
           ]
  end

  test "init app order is preserved" do
    release =
      @example_release |> Map.put(:options, shoehorn: [init: [:system_init, :optional_app]])

    result = Release.init(release)
    shoehorn_release = result.boot_scripts[:shoehorn]

    # system_init is started right before optional_app and both are at the beginning
    assert shoehorn_release == [
             kernel: :permanent,
             stdlib: :permanent,
             compiler: :permanent,
             elixir: :permanent,
             logger: :permanent,
             crypto: :permanent,
             shoehorn: :permanent,
             sasl: :permanent,
             system_init: :temporary,
             optional_app: :temporary,
             crash_app: :temporary,
             load_only_app: :load,
             pure_library: :temporary,
             some_app: :temporary,
             my_project: :temporary,
             iex: :none
           ]
  end

  test "last apps go towards the end" do
    release = @example_release |> Map.put(:options, shoehorn: [last: [:crash_app, :iex]])

    result = Release.init(release)
    shoehorn_release = result.boot_scripts[:shoehorn]

    # Apps are alphabetically sorted. iex is still last. crash_app is as far back as it can
    # go since my_project depends on crash_app
    assert shoehorn_release == [
             kernel: :permanent,
             stdlib: :permanent,
             compiler: :permanent,
             elixir: :permanent,
             logger: :permanent,
             crypto: :permanent,
             shoehorn: :permanent,
             sasl: :permanent,
             load_only_app: :load,
             optional_app: :temporary,
             pure_library: :temporary,
             some_app: :temporary,
             system_init: :temporary,
             crash_app: :temporary,
             my_project: :temporary,
             iex: :none
           ]
  end

  test "bad init apps raise" do
    release = @example_release |> Map.put(:options, shoehorn: [init: [nil]])
    assert_raise ReleaseError, fn -> Release.init(release) end

    release = @example_release |> Map.put(:options, shoehorn: [init: [:not_an_app]])
    assert_raise ReleaseError, fn -> Release.init(release) end

    release = @example_release |> Map.put(:options, shoehorn: [init: [{:m, :f, :a}]])
    assert_raise ReleaseError, fn -> Release.init(release) end
  end
end
