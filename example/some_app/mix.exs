defmodule SomeApp.MixProject do
  use Mix.Project

  def project do
    [
      app: :some_app,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {SomeApp.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:optional_app, path: "../optional_app", optional: true}
    ]
  end
end
