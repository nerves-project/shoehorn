defmodule BootloaderTest do
  use Bootloader.TestCase, async: false
  doctest Bootloader

  test "can build bootloader and start it" do
    in_fixture "simple_app", fn ->
      System.cmd("mix", ["deps.get"])
      System.cmd("mix", ["compile", "--silent"])
      System.cmd("mix", ["release", "--no-tar"])


    end
  end

end
