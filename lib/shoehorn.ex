defmodule Shoehorn do
  use Application

  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: Shoehorn.Supervisor]
    Supervisor.start_link(children(), opts)
  end

  def children() do
    :init.get_argument(:boot)
    |> boot()
  end

  def boot({:ok, [[bootfile]]}) do
    bootfile = to_string(bootfile)

    if String.ends_with?(bootfile, "shoehorn") do
      opts = Application.get_all_env(:shoehorn)

      [
        {Shoehorn.ApplicationController, opts}
      ]
    else
      []
    end
  end

  def boot(_), do: []

  # If distillery is present, load the plugin code
  if Code.ensure_loaded?(Distillery.Releases.Plugin) do
    defdelegate before_assembly(release, opts), to: Shoehorn.Plugin
    defdelegate after_assembly(release, opts), to: Shoehorn.Plugin
    defdelegate before_package(release, opts), to: Shoehorn.Plugin
    defdelegate after_package(release, opts), to: Shoehorn.Plugin
    defdelegate after_cleanup(release, opts), to: Shoehorn.Plugin
  end

  def all_applications_started? do
    Shoehorn.ApplicationController.status() == :app
  end
end
