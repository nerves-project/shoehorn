defmodule Shoehorn.Plugin do
  use Mix.Releases.Plugin

  defdelegate before_assembly(release, opts), to: Shoehorn
  defdelegate after_assembly(release, opts), to: Shoehorn
  defdelegate before_package(release, opts), to: Shoehorn
  defdelegate after_package(release, opts), to: Shoehorn
  defdelegate after_cleanup(release, opts), to: Shoehorn
end
