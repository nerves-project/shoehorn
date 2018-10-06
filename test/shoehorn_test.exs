Code.require_file("test/mix_test_helper.exs")

defmodule ShoehornTest do
  use Shoehorn.TestCase, async: false
  doctest Shoehorn

  import MixTestHelper

  @simple_app_path Path.join([File.cwd!(), "test", "fixtures", "simple_app"])

  defmacrop with_simple_app(body) do
    quote do
      old_dir = File.cwd!()
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
  # 5m
  @tag timeout: 60_000 * 5
  test "Can build and release with Shoehorn" do
    with_simple_app do
      result = mix("release", ["--verbose", "--env=prod"])

      r =
        case result do
          {:ok, output} ->
            {:ok, output}

          {:error, _code, output} ->
            IO.puts(output)
            :error
        end

      assert {:ok, _output} = r

      app_path = Path.join([@simple_app_path, "_build/prod/rel/simple_app/bin/simple_app"])
      boot_file = Path.join([@simple_app_path, "_build/prod/rel/simple_app/bin/shoehorn"])

      {:ok, _task} =
        Task.start(fn ->
          System.cmd(app_path, ["console_boot", boot_file])
        end)

      :timer.sleep(2000)
      assert {"pong\n", 0} = System.cmd(app_path, ["ping"])

      assert {applications, 0} =
               System.cmd(app_path, ["rpc", "Application.started_applications()"])

      assert applications =~ "shoehorn"
      assert applications =~ "simple_app"

      System.cmd(app_path, ["stop"])
      :timer.sleep(1000)
    end
  end

  @tag :expensive
  # 5m
  @tag timeout: 60_000 * 5
  test "Can build and release without Shoehorn" do
    with_simple_app do
      result = mix("release", ["--verbose", "--env=prod"])

      r =
        case result do
          {:ok, output} ->
            {:ok, output}

          {:error, _code, output} ->
            IO.puts(output)
            :error
        end

      assert {:ok, _output} = r

      app_path = Path.join([@simple_app_path, "_build/prod/rel/simple_app/bin/simple_app"])

      {:ok, _task} =
        Task.start(fn ->
          System.cmd(app_path, ["console"])
        end)

      :timer.sleep(1000)
      assert {"pong\n", 0} = System.cmd(app_path, ["ping"])

      assert {app_controller_pid, 0} =
               System.cmd(app_path, [
                 "rpc",
                 "Process.whereis(Shoehorn.ApplicationController)"
               ])

      assert app_controller_pid == "nil\n"

      System.cmd(app_path, ["stop"])
      :timer.sleep(1000)
    end
  end
end
