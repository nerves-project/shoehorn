defmodule Bootloader.Application do
  alias Bootloader.Application.Modules
  alias Bootloader.Utils

  defstruct [name: nil, hash: nil, priv_dir: nil, applications: [], modules: []]

  def load(app) do
    Application.load(app)
    applications = applications(app)
    modules = modules(app)
    priv_dir = priv_dir(app)
    hash = hash(modules, applications, priv_dir)
    %__MODULE__{
      name: app,
      applications: applications,
      modules: modules,
      hash: hash,
      priv_dir: priv_dir
    }
  end

  def hash(modules, applications, priv_dir) do
    blob =
      (modules ++ applications ++ [priv_dir])
      |> Enum.map(& &1.hash)
      |> Enum.join

    :crypto.hash(:sha256, blob)
    |> Base.encode16
  end

  defp applications(app) do
    spec = Application.spec(app)
    applications =
      Keyword.get(spec, :applications, []) ++
      Keyword.get(spec, :included_applications, [])
    applications = Enum.reject(applications, & &1 in Utils.bootloader_applications())
    Enum.map(applications, &Bootloader.Application.load/1)
  end

  def modules(app) do
    Application.spec(app)[:modules]
    |> Enum.map(&Bootloader.Application.Module.load/1)
  end

  def priv_dir(app) do
    Bootloader.Application.PrivDir.load(app)
  end

end
