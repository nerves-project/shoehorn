defmodule Shoehorn.MixProject do
  use Mix.Project

  @version "0.9.2"
  @source_url "https://github.com/nerves-project/shoehorn"

  def project do
    [
      app: :shoehorn,
      version: @version,
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      description: description(),
      package: package(),
      deps: deps(),
      docs: docs(),
      dialyzer: dialyzer(),
      preferred_cli_env: %{
        "coveralls.circle": :test,
        docs: :docs,
        "hex.publish": :docs,
        "hex.build": :docs
      }
    ]
  end

  def application do
    [extra_applications: [:crypto, :logger], mod: {Shoehorn.Application, []}]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:credo, "~> 1.6", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4.0", only: :dev, runtime: false},
      {:ex_doc, "~> 0.22", only: :docs, runtime: false}
    ]
  end

  defp docs do
    [
      extras: ["README.md", "CHANGELOG.md"],
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end

  defp description do
    "Shoehorn helps you handle OTP application failures"
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp dialyzer() do
    [
      flags: [:missing_return, :extra_return, :unmatched_returns, :error_handling, :underspecs],
      plt_add_apps: [:mix]
    ]
  end
end
