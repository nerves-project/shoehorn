defmodule Shoehorn.Release do
  @moduledoc false

  alias Shoehorn.Utils

  def init(%{boot_scripts: boot_scripts, applications: applications} = release) do
    boot_scripts =
      Map.put(boot_scripts, :shoehorn, start_apps(applications) ++ load_apps(applications))

    %{release | boot_scripts: boot_scripts}
  end

  def start_apps(applications) do
    Enum.filter(applications, fn {name, _opts} ->
      name in Utils.shoehorn_applications()
    end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.map(&{&1, :permanent})
  end

  def load_apps(applications) do
    Enum.reject(applications, fn {name, _opts} ->
      name in Utils.shoehorn_applications()
    end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.map(&{&1, :temporary})
  end
end
