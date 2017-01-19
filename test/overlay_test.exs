defmodule Bootloader.OverlayTest do
  use Bootloader.TestCase, async: false

  setup_all do
    overlay_fixture_path =
      Path.join([File.cwd!, "test", "fixtures", "overlay"])

    source_path =
      Path.join([overlay_fixture_path, "source", "simple_app"])
    target_path =
      Path.join([overlay_fixture_path, "target", "simple_app"])

    [source_path, target_path]
    |> Enum.each(fn(path) ->
      ebin = Path.join(path, "ebin")
      remove_beams(ebin)
      File.mkdir_p!(ebin)

      src = Path.join(path, "src")
      compile_path(src, ebin)
    end)
    {:ok, node} = :net_kernel.start([:"host@127.0.0.1"])
    [source: source_path, target: target_path, host_node: node]
  end

  test "Can apply overlay", context do
    overlay_dir = Path.join([context.target, "overlays"])
    |> IO.inspect
    File.mkdir_p!(overlay_dir)
    {:ok, source_node} = spawn_node(:"source@127.0.0.1", overlay_dir)
    {:ok, target_node} = spawn_node(:"target@127.0.0.1", overlay_dir)

    add_code_path(source_node, Path.join([context.source, "ebin"]))
    add_code_path(target_node, Path.join([context.target, "ebin"]))

    Bootloader.Utils.rpc(source_node, :application, :start, [:simple_app])
    Bootloader.Utils.rpc(target_node, :application, :start, [:simple_app])

    sources =
      Bootloader.Utils.rpc(source_node, Bootloader.ApplicationController, :applications, [])

    targets =
      Bootloader.Utils.rpc(target_node, Bootloader.ApplicationController, :applications, [])

    overlay =
      Bootloader.Utils.rpc(source_node, Bootloader.Overlay, :load, [sources, targets])

    Bootloader.Utils.rpc(target_node, Bootloader.Overlay, :apply, [overlay, overlay_dir])

    assert {SimpleApp.Modified, :source, :pong} == Bootloader.Utils.rpc(target_node, SimpleApp.Modified, :ping, [])
    assert {SimpleApp.Inserted, :source, :pong} == Bootloader.Utils.rpc(target_node, SimpleApp.Inserted, :ping, [])
    #assert_raise RuntimeError, fn() ->
      Bootloader.Utils.rpc(target_node, SimpleApp.Deleted, :ping, [])
      |> IO.inspect
    #end
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
  # test "Can create an overlay delta" do
  #   sources = [
  #     %Bootloader.Application{applications: [],
  #       hash: "B551B4ADCCC853CBE8F8F47E19564FBBB59B2587BC61956DAC4DD8F492AB14C9",
  #       modules: [
  #         %Bootloader.Application.Module{
  #           hash: 113844003775912711108713157198168575621,
  #           name: SimpleApp.A},
  #         %Bootloader.Application.Module{
  #           hash: 689416378326893794310789317689436898974,
  #           name: SimpleApp.B}],
  #       name: :simple_app,
  #       priv_dir: %Bootloader.Application.PrivDir{
  #         files: [
  #           %Bootloader.Application.PrivDir.File{binary: nil,
  #           hash: "8470D56547EEA6236D7C81A644CE74670CA0BBDA998E13C629EF6BB3F0D60B6",
  #           path: "text"},
  #           %Bootloader.Application.PrivDir.File{binary: nil,
  #           hash: "8470D56547EEA6236D7C81A644CE74670CA0BBDA998E13C629EF6BB3F0D603245",
  #           path: "text2"}],
  #         hash: "5EC3F2B6946F61D6D8B9ECE112A434E245C07CC566395E79506B9DB6A4D015DA",
  #         path: "/Users/jschneck/Developer/nerves/bootloader/test/fixtures/simple_app/_build/dev/lib/simple_app/priv"}}]
  #
  #   targets = [
  #     %Bootloader.Application{applications: [],
  #       hash: "5EC3F2B6946F61D6D8B9ECE112A434E245C07CC566395E79506B9DB6A4D015DA",
  #       modules: [
  #         %Bootloader.Application.Module{
  #           hash: 113844003775912711108713157198168575621,
  #           name: SimpleApp.A},
  #         %Bootloader.Application.Module{
  #           hash: 167008704125844426985131157525154896684,
  #           name: SimpleApp.B}],
  #       name: :simple_app,
  #       priv_dir: %Bootloader.Application.PrivDir{
  #         files: [
  #           %Bootloader.Application.PrivDir.File{binary: nil,
  #           hash: "8470D56547EEA6236D7C81A644CE74670CA0BBDA998E13C629EF6BB3F0D60B69",
  #           path: "text"}],
  #         hash: "B551B4ADCCC853CBE8F8F47E19564FBBB59B2587BC61956DAC4DD8F492AB14C9",
  #         path: "/Users/jschneck/Developer/nerves/bootloader/test/fixtures/simple_app/_build/dev/lib/simple_app/priv"}}]
  #
  #   Bootloader.Overlay.load(sources, targets)
  # end
end
