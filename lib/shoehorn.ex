defmodule Shoehorn do
  use Application

  @impl Application
  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: Shoehorn.Supervisor]
    Supervisor.start_link(children(), opts)
  end

  defp children() do
    case :init.get_argument(:boot) do
      {:ok, [[bootfile]]} ->
        bootfile = to_string(bootfile)

        if String.ends_with?(bootfile, "shoehorn") do
          opts = Application.get_all_env(:shoehorn)

          :error_logger.add_report_handler(Shoehorn.Handler.Proxy, opts)

          [
            {Shoehorn.ApplicationController, opts}
          ]
        else
          []
        end

      _ ->
        []
    end
  end
end
