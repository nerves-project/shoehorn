defmodule MyProject.RestartHandler do
  use Shoehorn.Handler

  require Logger

  def init(_opts) do
    {:ok, %{restart_counts: 0}}
  end

  def application_started(app, s) do
    Logger.info("Application started: #{inspect(app)}")
    {:continue, s}
  end

  def application_exited(:crash_app, _reason, state) do
    Logger.info(
      ":crash_app exited. Run Application.ensure_all_started(:crash_app) yourself to restart."
    )

    {:continue, state}
  end

  def application_exited(app, _reason, state) do
    if state.restart_counts < 5 do
      Logger.info("Application #{app} stopped, but going to restart it.")
      Application.ensure_all_started(app)
      {:continue, %{state | restart_counts: state.restart_counts + 1}}
    else
      Logger.info("Application #{app} stopped and I'm done.")
      {:halt, state}
    end
  end
end
