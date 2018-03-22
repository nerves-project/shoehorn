defmodule Shoehorn.ApplicationController do
  use GenServer

  @timeout 30_000
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
    :error_logger.add_report_handler(Shoehorn.Handler.Proxy, opts)

    app = app(opts[:app])

    init = opts[:init] || []
    init = reject_missing_apps(init)

    overlay_path = opts[:overlay_path] || @overlay_path

    s = %{
      init: init,
      app: app,
      hash: nil,
      applications: [],
      overlay_path: overlay_path,
      status: :init
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
    Enum.each(s.init, &start_app/1)
    send(self(), :app)
    {:noreply, %{s | status: :app}}
  end

  def handle_info(:app, s) do
    start_app(s.app)
    {:noreply, build_cache(s)}
  end

  def handle_info(_unknown, s) do
    {:noreply, s}
  end

  defp start_app({m, f, a}) when is_list(a) do
    apply(m, f, a)
  end

  defp start_app({m, a}) when is_list(a) do
    apply(m, :start_link, a)
  end

  defp start_app(app) when is_atom(app) do
    Application.ensure_all_started(app)
  end

  defp start_app(init_call) do
    IO.puts("""
    Shoehorn encountered an error while trying to call #{inspect(init_call)}
    during initialization. The argument needs to be formated as

    {Module, :function, [args]}
    {Module, [args]}
    :application
    """)

    :ok
  end

  defp build_cache(s) do
    applications_list = [s.app | filter_apps(s.init)]
    hash = build_hash(applications_list)
    applications = build_applications(applications_list)
    %{s | hash: hash, applications: applications}
  end

  defp build_hash(application_list) do
    application_list
    |> Enum.map(&Shoehorn.Application.load/1)
    |> Enum.map(& &1.hash)
    |> Enum.join()
    |> Utils.hash()
  end

  defp build_applications(application_list) do
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
end
