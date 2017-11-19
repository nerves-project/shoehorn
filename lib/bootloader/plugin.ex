defmodule Bootloader.Plugin do
  use Mix.Releases.Plugin

  defdelegate before_assembly(release, opts), to: Bootloader
  defdelegate after_assembly(release, opts), to: Bootloader
  defdelegate before_package(release, opts), to: Bootloader
  defdelegate after_package(release, opts), to: Bootloader
  defdelegate after_cleanup(release, opts), to: Bootloader
end
