defmodule Bootloader.Application do
  use GenServer

  alias Bootloader.Application.Modules

  defstruct [app: nil, modules: []]

  def load(app) do
    Application.load(app)
    spec = Application.spec(app)
    modules =
      spec[:modules]
      |> Enum.map(&Bootloader.Application.Module.load/1)
    %__MODULE__{
      app: app,
      modules: modules
    }
  end

  def start_link(app) do
    app = load(app)
    GenServer.start_link(__MODULE__, app)
  end

  def init(app) do
    {:ok, app}
  end
end
