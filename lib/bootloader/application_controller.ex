defmodule Bootloader.ApplicationController do
  use GenServer
  @timeout 30_000
  alias Bootloader.Utils

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
    app = opts[:app]
    init =  opts[:init] || []
    overlay_path = opts[:overlay_path]
    handler = opts[:handler] || Bootloader.Handler

    s = %{
      init: init,
      app: app,
      hash: nil,
      applications: nil,
      overlay_path: overlay_path,
      handler: handler,
      handler_state: handler.init()
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
    reply = Bootloader.Overlay.apply(overlay, s.overlay_path)
    Application.stop(s.app)
    Application.ensure_all_started(s.app)
    {:reply, reply, build_cache(s)}
  end

  # Bootloader Application Init Phase
  def handle_info(:init, s) do
    for app <- s.init do
      Application.ensure_all_started(app)
    end
    send(self(), :app)
    {:noreply, s}
  end

  # Bootloader Application Start Phase
  def handle_info(:app, s) do
    Application.ensure_all_started(s.app)
    {:noreply, build_cache(s)}
  end

  defp build_cache(s) do
    applications_list = [s.app | s.init]
    hash = build_hash(applications_list)
    applications = build_applications(applications_list)
    %{s | hash: hash, applications: applications}
  end

  defp build_hash(application_list) do
    application_list
    |> Bootloader.Application.expand_applications(application_list)
    |> Enum.map(&Bootloader.Application.load/1)
    |> Enum.map(& &1.hash)
    |> Enum.join
    |> Utils.hash
  end

  defp build_applications(application_list) do
    application_list
    |> Bootloader.Application.expand_applications(application_list)
    |> Enum.map(&Bootloader.Application.load/1)
  end

end
