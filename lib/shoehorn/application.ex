defmodule Shoehorn.Application do
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    if using_shoehorn?() do
      opts = Application.get_all_env(:shoehorn)
      :error_logger.add_report_handler(Shoehorn.ReportHandler, opts)
    end

    opts = [strategy: :one_for_one, name: Shoehorn.Supervisor]
    Supervisor.start_link([], opts)
  end

  defp using_shoehorn?() do
    case :init.get_argument(:boot) do
      {:ok, [[bootfile]]} ->
        bootfile = to_string(bootfile)

        String.ends_with?(bootfile, "shoehorn")

      _ ->
        false
    end
  end
end
