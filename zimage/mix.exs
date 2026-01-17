defmodule Zimage.MixProject do
  use Mix.Project

  def project do
    [
      app: :zimage,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Zimage.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:pythonx, "~> 0.4.7"},
      {:jason, "~> 1.4.4"},
      {:req, "~> 0.5.0"},
      {:opentelemetry_api, "~> 1.3"},
      {:opentelemetry, "~> 1.3"},
      {:opentelemetry_exporter, "~> 1.0"},
    ]
  end
end