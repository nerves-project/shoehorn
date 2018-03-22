defmodule Example.ShoehornHandler do
  use Shoehorn.Handler

  def init(_opts) do
    {:ok, %{restart_counts: 0}}
  end

  def application_started(app, s) do
    IO.puts "Application started: #{inspect app}"
    {:continue, s}
  end

  def application_exited(app, _reason, %{restart_counts: restart_counts} = state)
      when restart_counts < 2 do
    IO.puts("Application stopped: #{inspect(app)} #{inspect(state)}")
    Application.ensure_all_started(app)
    {:continue, %{state | restart_counts: restart_counts + 1}}
  end

  def application_exited(app, _reason, %{restart_counts: restart_counts} = state)
      when restart_counts < 4 do
    IO.puts("Application stopped: #{inspect(app)} #{inspect(state)}")
    Application.ensure_all_started(app)
    {:continue, %{state | restart_counts: restart_counts + 1}}
  end

  def application_exited(app, _reason, state) do
    IO.puts("Application stopped forever: #{inspect(app)} #{inspect(state)}")
    {:halt, state}
  end
end
