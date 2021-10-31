defmodule Shoehorn do
  use Application

  @impl Application
  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: Shoehorn.Supervisor]
    Supervisor.start_link(children(), opts)
  end

  defp children() do
    :init.get_argument(:boot)
    |> boot()
  end

  defp boot({:ok, [[bootfile]]}) do
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

  defp boot(_), do: []
end
