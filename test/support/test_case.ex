defmodule Shoehorn.TestCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  @compile {:no_warn_undefined, {Mix.ProjectStack, :clear_cache, 0}}

  using do
    quote do
      import unquote(__MODULE__)
      alias Shoehorn.TestCase
    end
  end

  setup config do
    if apps = config[:apps] do
      Logger.remove_backend(:console)
    end

    on_exit(fn ->
      _ = Application.start(:logger)
      Mix.env(:dev)
      Mix.Task.clear()
      Mix.Shell.Process.flush()
      Mix.State.clear_cache()

      Mix.ProjectStack.clear_stack()
      _ = delete_tmp_paths()

      if apps do
        Enum.each(apps, fn app ->
          _ = Application.stop(app)
          Application.unload(app)
        end)

        Logger.add_backend(:console, flush: true)
      end
    end)

    :ok
  end

  defmacro in_fixture(which, block) do
    module = inspect(__CALLER__.module)
    function = Atom.to_string(elem(__CALLER__.function, 0))
    tmp = Path.join(module, function)

    quote do
      unquote(__MODULE__).in_fixture(unquote(which), unquote(tmp), unquote(block))
    end
  end

  def in_fixture(which, tmp, function) do
    dest =
      tmp_path(tmp)
      |> Path.join(which)

    fixture_to_tmp(which, dest)

    flag = String.to_charlist(tmp_path())

    get_path = :code.get_path()
    previous = :code.all_loaded()

    try do
      File.cd!(dest, function)
    after
      cwd = File.cwd!()

      _ = File.rm_rf!(Path.join(cwd, "deps"))
      _ = File.rm_rf!(Path.join(cwd, "_build"))

      _ = :code.set_path(get_path)

      for {mod, file} <- :code.all_loaded() -- previous,
          file == :in_memory or (is_list(file) and :lists.prefix(flag, file)) do
        purge([mod])
      end
    end
  end

  def fixture_path do
    Path.expand("../fixtures", __DIR__)
  end

  def fixture_path(extension) do
    Path.join(fixture_path(), extension)
  end

  def tmp_path do
    Path.expand("../tmp", __DIR__)
  end

  def tmp_path(extension) do
    Path.join(tmp_path(), to_string(extension))
  end

  def fixture_to_tmp(fixture, dest) do
    src = fixture_path(fixture)

    _ = File.rm_rf!(dest)
    File.mkdir_p!(dest)
    _ = File.cp_r!(src, dest)

    :ok
  end

  def purge(modules) do
    Enum.each(modules, fn m ->
      :code.purge(m)
      :code.delete(m)
    end)
  end

  defp delete_tmp_paths do
    tmp = String.to_charlist(tmp_path())
    for path <- :code.get_path(), :string.str(path, tmp) != 0, do: :code.del_path(path)
  end
end

defmodule ShoehornTest.Handler do
  @moduledoc false
  @behaviour Shoehorn.Handler

  @impl Shoehorn.Handler
  def init(_opts) do
    {:ok, nil}
  end

  @impl Shoehorn.Handler
  def application_started(_app, state) do
    {:continue, state}
  end

  @impl Shoehorn.Handler
  def application_exited(_app, _reason, state) do
    {:continue, state}
  end
end
