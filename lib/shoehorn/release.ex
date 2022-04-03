defmodule Shoehorn.Release do
  @moduledoc false

  # These applications are unrecoverable using shoehorn
  @permanent_applications [
    :shoehorn,
    :runtime_tools,
    :kernel,
    :stdlib,
    :compiler,
    :elixir,
    :iex,
    :crypto,
    :logger,
    :sasl
  ]

  def init(%{boot_scripts: boot_scripts, applications: applications} = release) do
    boot_scripts =
      Map.put(boot_scripts, :shoehorn, start_apps(applications) ++ load_apps(applications))

    %{release | boot_scripts: boot_scripts}
  end

  def start_apps(applications) do
    Enum.filter(applications, fn {name, _opts} ->
      name in @permanent_applications
    end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.map(&{&1, :permanent})
  end

  def load_apps(applications) do
    Enum.reject(applications, fn {name, _opts} ->
      name in @permanent_applications
    end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.map(&{&1, :none})
  end
end
