defmodule MyProject.MixProject do
  use Mix.Project

  def project do
    [
      app: :my_project,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {MyProject.Application, []}
    ]
  end

  def releases do
    [
      my_project: [
        overwrite: true,
        quiet: true,
        steps: [&Shoehorn.Release.init/1, :assemble]
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:crash_app, path: "../crash_app"},
      {:shoehorn, path: "../.."},
      {:system_init, path: "../system_init"}
    ]
  end
end
