defmodule Bootloader do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    opts = Application.get_all_env(:bootloader)
    children = [
      worker(Bootloader.ApplicationController, [opts])
    ]

    opts = [strategy: :one_for_one, name: Bootloader.Supervisor]
    Supervisor.start_link(children, opts)
  end

end
