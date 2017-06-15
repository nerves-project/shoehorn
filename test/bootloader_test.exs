Code.require_file("test/mix_test_helper.exs")

defmodule BootloaderTest do
  use Bootloader.TestCase, async: false
  doctest Bootloader

  import MixTestHelper

  @simple_app_path Path.join([File.cwd!, "test", "fixtures", "simple_app"])

  defmacrop with_simple_app(body) do
    quote do
      old_dir = File.cwd!
      File.cd!(@simple_app_path)
      {:ok, _} = File.rm_rf(Path.join(@simple_app_path, "_build"))
      _ = File.rm(Path.join(@simple_app_path, "mix.lock"))
      {:ok, _} = mix("deps.get")
      {:ok, _} = mix("deps.compile")
      {:ok, _} = mix("compile")
      {:ok, _} = mix("release.clean")
      unquote(body)
      File.cd!(old_dir)
    end
  end


  @tag :expensive
  @tag timeout: 60_000 * 5 # 5m
  test "Can build and release with Bootloader" do

    with_simple_app do
      result = mix("release", ["--verbose", "--env=prod"])
      r = case result do
        {:ok, output} -> {:ok, output}
        {:error, _code, output} ->
          IO.puts(output)
          :error
      end

      assert {:ok, _output} = r

      app_path =
        Path.join([@simple_app_path, "_build/prod/rel/simple_app/bin/simple_app"])

      {:ok, _task} =
        Task.start(fn ->
          System.cmd(app_path, ["console_boot", "bootloader"])
        end)
      :timer.sleep(1000)
      assert {"pong\n", 0} = System.cmd(app_path, ["ping"])
      assert {applications, 0}    = System.cmd(app_path, ["eval", "'Elixir.Application':started_applications()"])

      assert applications =~ "bootloader"
      assert applications =~ "simple_app"

      System.cmd(app_path, ["stop"])
    end

  end

  @tag :expensive
  @tag timeout: 60_000 * 5 # 5m
  test "Can build and release without Bootloader" do

    with_simple_app do
      result = mix("release", ["--verbose", "--env=prod"])
      r = case result do
        {:ok, output} -> {:ok, output}
        {:error, _code, output} ->
          IO.puts(output)
          :error
      end

      assert {:ok, _output} = r

      app_path =
        Path.join([@simple_app_path, "_build/prod/rel/simple_app/bin/simple_app"])

      {:ok, _task} =
        Task.start(fn ->
          System.cmd(app_path, ["console"])
        end)
      :timer.sleep(1000)
      assert {"pong\n", 0} = System.cmd(app_path, ["ping"])
      assert {app_controller_pid, 0}    = System.cmd(app_path, ["eval", "'Elixir.Process':whereis('Elixir.Bootloader.ApplicationController')"])

      assert app_controller_pid == "nil\n"

      System.cmd(app_path, ["stop"])
    end

  end
end
