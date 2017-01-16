defmodule Bootloader.Application.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init([]) do
    children = [
      worker(Stack, [[:hello]])
    ]

    # supervise/2 is imported from Supervisor.Spec
    opts = [strategy: :simple_one_for_one]
    supervise(children, opts)
  end
end
