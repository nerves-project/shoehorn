defmodule Example.ShoehornHandler do
  @behaviour Shoehorn.Handler

  def init(_opts) do
   {:ok, %{restart_counts: 0}}
  end

  def handle_application(:not_started, app, state) do
    IO.puts "Application failed to start: #{inspect app} #{inspect state}"
    {:halt, state}
  end

  def handle_application({:stopped, reason}, app, %{restart_counts: restart_counts} = state) when restart_counts < 2 do
    IO.puts "Application stopped: #{inspect app} #{inspect state} #{inspect reason}"
    Shoehorn.ApplicationController.ensure_all_started(app)
    {:ok, %{state | restart_counts: restart_counts + 1}}
  end

  def handle_application({:stopped, reason}, app, %{restart_counts: restart_counts} = state) when restart_counts < 4 do
    IO.puts "Application restart: #{inspect app} #{inspect state} #{inspect reason}"
    Shoehorn.ApplicationController.ensure_all_started(app)
    {:restart, %{state | restart_counts: restart_counts + 1}}
  end

  def handle_application({:stopped, reason}, app, state) do
    IO.puts "Application stopped forever: #{inspect app} #{inspect state} #{inspect reason}"
    {:halt, state}
  end
end
