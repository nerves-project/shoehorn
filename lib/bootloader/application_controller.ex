defmodule Bootloader.ApplicationController do
  use GenServer

  defstruct [app: nil, init_apps: [], applications: [], phase: :boot, overlay_path: nil]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def update_module(mod, bin, opts) do
    GenServer.call({:mod, :update, {mod, bin, opts}})
  end

  def init(opts) do
    app = opts[:app]
    init =  opts[:init_apps] || []
    overlay_path = opts[:overlay_path]
    s = %__MODULE__{
      init_apps: init,
      app: app,
      overlay_path: overlay_path
    }

    send(self(), :init_start)

    {:ok, s}
  end

  def handle_call({:mod, :update, {mod, bin, opts}}, _from, s) do

    app = application_by_module(mod, s.applications)
    #Bootloader.Application.Module.update()

    {:reply, {:ok, mod}, s}
  end

  # Bootloader Application Init Phase
  def handle_info(:init_start, s) do
    IO.puts "Start Init Apps: #{inspect s.init_apps}"
    send(self(), :app_start)
    {:noreply, %{s | phase: :init}}
  end

  def handle_info(:app_start, s) do
    IO.puts "Start App: #{inspect s.app}"
    #{:ok, pid} = Bootloader.Application.start_link(s.app)
    #s = %{s | applications: update_applications(app, s.applications)}
    {:noreply, s}
  end

  defp application_by_module(mod, applications) do
    Enum.find(applications, fn(%{modules: modules}) ->
      Enum.any?(modules, & &1.module == mod)
    end)
  end

  defp update_applications(app, applications) do
    applicagtions =
      Enum.reject(applications, & &1.app == app.app)
    [app, applications]
  end

end
