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

  def application do
    [
      extra_applications: [:logger],
      mod: {MyProject.Application, []}
    ]
  end

  defp deps do
    [
      {:crash_app, path: "../crash_app"},
      {:load_only_app, path: "../load_only_app", runtime: false},
      {:shoehorn, path: "../.."},
      {:system_init, path: "../system_init"}
    ]
  end

  def releases do
    [
      my_project: [
        overwrite: true,
        quiet: true,
        steps: [&Shoehorn.Release.init/1, :assemble],
        applications: [
          # Direct the release generator to load this app, but not start it.
          # Shoehorn won't override this decision.
          load_only_app: :load
        ]
      ]
    ]
  end
end
