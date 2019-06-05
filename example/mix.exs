defmodule Example.MixProject do
  use Mix.Project

  def project do
    [
      app: :example,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Example, []},
      extra_applications: [:distillery, :logger]
    ]
  end

  def releases do
    [
      example: [
        overwrite: true,
        quiet: true,
        steps: [&Shoehorn.Release.init/1, :assemble]
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:shoehorn, path: "../"},
      {:distillery, "~> 2.1"},
    ]
  end
end
