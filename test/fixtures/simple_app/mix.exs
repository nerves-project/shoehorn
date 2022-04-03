defmodule SimpleApp.MixProject do
  use Mix.Project

  def project do
    [
      app: :simple_app,
      version: "0.1.0",
      elixir: "~> 1.10",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  def releases do
    [
      simple_app: [
        include_executables_for: [:unix],
        overwrite: true,
        quiet: true,
        steps: [&Shoehorn.Release.init/1, :assemble]
      ]
    ]
  end

  defp deps do
    [
      {:shoehorn, path: "../../../"}
    ]
  end
end
