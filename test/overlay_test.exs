defmodule Bootloader.OverlayTest do
  use Bootloader.TestCase, async: true

  setup_all do
    overlay_fixture_path =
      Path.join([File.cwd!, "test", "fixtures", "overlay"])

    source_path =
      Path.join([overlay_fixture_path, "source", "simple_app"])
    target_path =
      Path.join([overlay_fixture_path, "target", "simple_app"])

    Path.join([target_path, "overlays"])
    |> File.rm_rf!()

    [source_path, target_path]
    |> Enum.each(fn(path) ->
      ebin = Path.join(path, "ebin")
      remove_beams(ebin)
      File.mkdir_p!(ebin)

      src = Path.join(path, "src")
      compile_path(src, ebin)
    end)
    {:ok, node} = :net_kernel.start([:"host@127.0.0.1"])
    overlay_dir = Path.join([target_path, "overlays"])

    File.mkdir_p!(overlay_dir)
    {:ok, source_node} = spawn_node(:"source@127.0.0.1", overlay_dir)
    {:ok, target_node} = spawn_node(:"target@127.0.0.1", overlay_dir)

    add_code_path(source_node, Path.join([source_path, "ebin"]))
    add_code_path(target_node, Path.join([target_path, "ebin"]))

    Bootloader.Utils.rpc(source_node, :application, :start, [:simple_app])
    Bootloader.Utils.rpc(target_node, :application, :start, [:simple_app])

    sources =
      Bootloader.Utils.rpc(source_node, Bootloader.ApplicationController, :applications, [])

    targets =
      Bootloader.Utils.rpc(target_node, Bootloader.ApplicationController, :applications, [])

    overlay =
      Bootloader.Utils.rpc(source_node, Bootloader.Overlay, :load, [sources, targets])

    overlay_dir = Path.join([target_path, "overlays"])
    assert :ok =
      Bootloader.Utils.rpc(
        target_node,
        Bootloader.Overlay,
        :apply,
        [overlay, overlay_dir])

    [source: source_path, target: target_path,
     overlay: overlay, sources: sources, targets: targets,
     source_node: source_node, target_node: target_node, host_node: node]
  end

  test "Module Modified Apply", context do
    assert {SimpleApp.Modified, :source, :pong} ==
      Bootloader.Utils.rpc(context.target_node, SimpleApp.Modified, :ping, [])
  end

  test "Module Insert Apply", context do
    assert {SimpleApp.Inserted, :source, :pong} ==
      Bootloader.Utils.rpc(context.target_node, SimpleApp.Inserted, :ping, [])
  end

  test "Module Delete Apply", context do
    assert :error = Bootloader.Utils.rpc(context.target_node, SimpleApp.Deleted, :ping, [])
  end

  test "PrivDir Modified Apply", context do
    target_priv_dir =  Bootloader.Utils.rpc(context.target_node, :code, :priv_dir, [:simple_app])

    file_modified = Path.join([target_priv_dir, "file_modified"])
    source_file_modified =
      Path.join([context.source, "priv", "file_modified"])
      |> File.read!
    assert Bootloader.Utils.rpc(context.target_node, File, :read!, [file_modified]) == source_file_modified
  end

  test "PrivDir Insert Apply", context do
    target_priv_dir =  Bootloader.Utils.rpc(context.target_node, :code, :priv_dir, [:simple_app])

    file_inserted = Path.join([target_priv_dir, "file_inserted"])
    source_file_inserted =
      Path.join([context.source, "priv", "file_inserted"])
      |> File.read!
    assert Bootloader.Utils.rpc(context.target_node, File, :read!, [file_inserted]) == source_file_inserted
  end

  test "PrivDir Deleted Apply", context do
    target_priv_dir = Bootloader.Utils.rpc(context.target_node, :code, :priv_dir, [:simple_app])
    file_deleted = Path.join([target_priv_dir, "file_deleted"])
    assert {:error, _} = Bootloader.Utils.rpc(context.target_node, File, :read, [file_deleted])
  end

  defp remove_beams(ebin) do
    Path.join([ebin, "*.beam"])
    |> Path.wildcard
    |> Enum.each(&File.rm!/1)

  end

  defp compile_path(src, ebin) do
    File.ls!(src)
    |> Enum.each(fn(file) ->
      path = Path.join([src, file])

      path
      |> File.read!
      |> Code.compile_string()
      |> Enum.each(fn({module, bin}) ->
        file = Path.join([ebin, "#{module}.beam"])
        File.write!(file, bin)
      end)
    end)
  end

  defp vm_args() do
    '-setcookie #{:erlang.get_cookie()}'
  end

  defp spawn_node(node_host, config) do
    {:ok, node} = :slave.start('127.0.0.1', node_name(node_host), vm_args())
    add_code_paths(node)
    transfer_config(node, config)
    ensure_applications_started(node)
    {:ok, node}
  end

  defp transfer_config(node, config) do
    Bootloader.Utils.rpc(node, Application, :put_env, [:bootloader, :app, :simple_app])
    Bootloader.Utils.rpc(node, Application, :put_env, [:bootloader, :overlay_path, config])
  end

  defp add_code_paths(node) do
    Bootloader.Utils.rpc(node, :code, :add_paths, [:code.get_path()])
  end

  defp add_code_path(node, path) do
    path = String.to_char_list(path)
    Bootloader.Utils.rpc(node, :code, :add_path, [path])
  end

  defp ensure_applications_started(node) do
    Bootloader.Utils.rpc(node, Application, :ensure_all_started, [:mix])
    Bootloader.Utils.rpc(node, Mix, :env, [Mix.env()])
    for {app_name, _, _} <- Application.loaded_applications do
      Bootloader.Utils.rpc(node, Application, :ensure_all_started, [app_name])
    end
  end

  defp node_name(node_host) do
    node_host
    |> to_string
    |> String.split("@")
    |> Enum.at(0)
    |> String.to_atom
  end

end
