defmodule Bootloader do
  use Application

  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: Bootloader.Supervisor]
    Supervisor.start_link(children(), opts)
  end

  def children() do
    :init.get_argument(:boot)
    |> boot()
  end

  def boot({:ok, [[bootfile]]}) do
    bootfile = to_string(bootfile)
    if String.ends_with?(bootfile, "bootloader") do
      import Supervisor.Spec, warn: false
      
      opts = Application.get_all_env(:bootloader)
      [worker(Bootloader.ApplicationController, [opts])]
    else
      []
    end
  end

  def boot(_), do: []

end
