defmodule Shoehorn.ApplicationController do
  use GenServer

  @timeout 30_000
  @shutdown_timer 30_000
  @overlay_path "/tmp/shoehorn"

  alias Shoehorn.Utils

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def hash() do
    GenServer.call(__MODULE__, :hash)
  end

  def clear_cache() do
    GenServer.call(__MODULE__, :clear_cache)
  end

  def applications() do
    GenServer.call(__MODULE__, :applications, @timeout)
  end

  def apply_overlay(overlay) do
    GenServer.call(__MODULE__, {:overlay, :apply, overlay}, @timeout)
  end

  def init(opts) do
    app = app(opts[:app])

    init = opts[:init] || []
    init = reject_missing_apps(init)

    shutdown_timer = opts[:shutdown_timer] || @shutdown_timer

    overlay_path = opts[:overlay_path] || @overlay_path
    handler = opts[:handler] || Shoehorn.Handler
    Enum.each([app | filter_apps(init)], &Application.load/1)

    s = %{
      init: init,
      app: app,
      hash: nil,
      applications: [],
      overlay_path: overlay_path,
      handler: handler,
      monitors: [],
      shutdown_timer: shutdown_timer,
      status: :run
    }

    send(self(), :init)
    {:ok, s}
  end

  def handle_call(:hash, _from, s) do
    {:reply, s.hash, s}
  end

  def handle_call(:applications, _from, s) do
    {:reply, s.applications, s}
  end

  def handle_call(:clear_cache, _from, s) do
    {:reply, :ok, build_cache(s)}
  end

  def handle_call({:overlay, :apply, overlay}, _from, s) do
    reply = Shoehorn.Overlay.apply(overlay, s.overlay_path)
    Application.stop(s.app)
    Application.ensure_all_started(s.app)
    {:reply, reply, build_cache(s)}
  end

  # Shoehorn Application Init Phase
  def handle_info(:init, s) do
    s = Enum.reduce(s.init, s, &start_app/2)
    send(self(), :app)
    {:noreply, s}
  end

  # Shoehorn Application Start Phase
  def handle_info(:app, %{status: :shutdown} = s), do: {:noreply, s}

  def handle_info(:app, s) do
    s = start_app(s.app, s)
    {:noreply, build_cache(s)}
  end

  # Application stopped
  def handle_info({:DOWN, _ref, _, _, _}, %{status: :shutdown} = s), do: {:noreply, s}
  def handle_info({:DOWN, ref, _, _, _}, s) do
    app = Enum.find(s.monitors, fn {_, app_ref} -> app_ref == ref end)
    {app, _} = app
    {:noreply, shutdown(app, s)}
  end

  def handle_info(:shutdown, s) do
    :erlang.halt()
    {:stop, :kill, s}
  end

  defp start_app(_, %{status: :shutdown} = s), do: s

  defp start_app({m, f, a}, s) when is_list(a) do
    apply(m, f, a)
    s
  end

  defp start_app({m, a}, s) when is_list(a) do
    apply(m, :start_link, a)
    s
  end

  defp start_app(app, s) when is_atom(app) do
    case Application.ensure_all_started(s.app) do
      {:ok, apps} ->
        monitors = monitor_applications(apps, s.monitors)
        %{s | monitors: monitors}

      _ ->
        shutdown(app, s)
    end
  end

  defp start_app(init_call, s) do
    IO.puts("""
    Shoehorn encountered an error while trying to call #{inspect(init_call)}
    during initialization. The argument needs to be formated as

    {Module, :function, [args]}
    {Module, [args]}
    :application
    """)

    s
  end

  defp shutdown(app, s) do
    shoehorn = self()

    # start the shutdown timer
    Process.send_after(shoehorn, :shutdown, s.shutdown_timer)

    spawn(fn ->
      apply(s.handler, :application_stopped, [app])
      send(shoehorn, :shutdown)
    end)

    %{s | status: :shutdown}
  end

  defp build_cache(s) do
    applications_list = [s.app | filter_apps(s.init)]
    hash = build_hash(applications_list)
    applications = build_applications(applications_list)
    %{s | hash: hash, applications: applications}
  end

  defp build_hash(application_list) do
    # |> Shoehorn.Application.expand_applications(application_list)
    application_list
    |> Enum.map(&Shoehorn.Application.load/1)
    |> Enum.map(& &1.hash)
    |> Enum.join()
    |> Utils.hash()
  end

  defp build_applications(application_list) do
    # |> Shoehorn.Application.expand_applications(application_list)
    application_list
    |> Enum.map(&Shoehorn.Application.load/1)
  end

  def app(nil) do
    IO.puts("[Shoehorn] app undefined. Finished booting")
    :shoehorn
  end

  def app(app) do
    if Shoehorn.Application.exists?(app) do
      app
    else
      IO.puts("[Shoehorn] app undefined. Finished booting")
      :shoehorn
    end
  end

  def filter_apps(apps) do
    Enum.filter(apps, fn
      app when is_atom(app) -> true
      _ -> false
    end)
  end

  def reject_missing_apps(apps) do
    Enum.filter(apps, fn
      app when is_atom(app) ->
        if Shoehorn.Application.exists?(app) do
          true
        else
          IO.puts("[Shoehorn] Init app #{inspect(app)} undefined. Skipping")
          false
        end

      _ ->
        true
    end)
  end

  def monitor_applications(applications, monitors) do
    Enum.reduce(applications, monitors, fn app, monitors ->
      case :application_controller.get_master(app) do
        pid when is_pid(pid) ->
          Keyword.put(monitors, app, Process.monitor(pid))

        _ ->
          monitors
      end
    end)
  end
end
