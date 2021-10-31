defmodule Shoehorn.ApplicationController do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    :error_logger.add_report_handler(Shoehorn.Handler.Proxy, opts)

    app = app(opts[:app])

    init = opts[:init] || []
    init = reject_missing_apps(init)

    s = %{
      init: init,
      app: app,
      status: :init
    }

    send(self(), :init)
    {:ok, s}
  end

  # Shoehorn Application Init Phase
  def handle_info(:init, s) do
    Enum.each(s.init, &start_app/1)
    send(self(), :app)
    {:noreply, %{s | status: :app}}
  end

  def handle_info(:app, s) do
    start_app(s.app)
    {:noreply, s}
  end

  def handle_info(_unknown, s) do
    {:noreply, s}
  end

  defp start_app({m, f, a}) when is_list(a) do
    apply(m, f, a)
  end

  defp start_app({m, a}) when is_list(a) do
    apply(m, :start_link, a)
  end

  defp start_app(app) when is_atom(app) do
    Application.ensure_all_started(app)
  end

  defp start_app(init_call) do
    IO.puts("""
    Shoehorn encountered an error while trying to call #{inspect(init_call)}
    during initialization. The argument needs to be formatted as

    {Module, :function, [args]}
    {Module, [args]}
    :application
    """)

    :ok
  end

  def app(nil) do
    IO.puts("[Shoehorn] app undefined. Finished booting")
    :shoehorn
  end

  def app(app) do
    if application_exists?(app) do
      app
    else
      IO.puts("[Shoehorn] app undefined. Finished booting")
      :shoehorn
    end
  end

  def filter_apps(apps) do
    Enum.filter(apps, fn
      app when is_atom(app) -> true
      _ -> false
    end)
  end

  def reject_missing_apps(apps) do
    Enum.filter(apps, fn
      app when is_atom(app) ->
        if application_exists?(app) do
          true
        else
          IO.puts("[Shoehorn] Init app #{inspect(app)} undefined. Skipping")
          false
        end

      _ ->
        true
    end)
  end

  def application_exists?(nil), do: false

  def application_exists?(app) do
    application_spec(app) != nil
  end

  def application_spec(app) do
    try do
      {:ok, application_spec} =
        Path.join([application_ebin(app), "#{app}.app"])
        |> :file.consult()

      {_, _, application_spec} =
        Enum.find(application_spec, fn
          {:application, ^app, _} -> true
          _ -> false
        end)

      application_spec
    rescue
      _ ->
        Application.load(app)
        Application.spec(app)
    end
  end

  def application_lib_dir(app) do
    :code.lib_dir(app)
  end

  def application_ebin(app) do
    Path.join([application_lib_dir(app), "ebin"])
  end
end
