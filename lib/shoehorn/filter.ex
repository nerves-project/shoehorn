defmodule Shoehorn.Filter do
  @moduledoc false

  @doc """
  A filter for handling Application.start/1,2 and Application.stop/1 events. Always return :ignore so that other filters
  can continue to handle the events as they please.
  """
  def filter(_event = %{msg: msg}, _extra) do
    maybe_log_message(msg)
    :ignore
  end

  def filter(_event, _extra) do
    :ignore
  end

  def maybe_log_message(
        {:report,
         %{
           label: {:application_controller, :progress},
           report: [application: app, started_at: _node]
         }}
      ) do
    GenServer.cast(Shoehorn.ReportHandler, {:started, app})
  end

  def maybe_log_message(
        {:report,
         %{
           label: {:application_controller, :exit},
           report: [application: app, exited: reason, type: _type]
         }}
      ) do
    GenServer.cast(Shoehorn.ReportHandler, {:exit, app, reason})
  end

  def maybe_log_message(_msg) do
    :ok
  end
end
