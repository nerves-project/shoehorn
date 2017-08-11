defmodule Bootloader.Plugin do
  use Mix.Releases.Plugin
  
  defdelegate after_assembly(_release, _opts), to: Bootloader
end
