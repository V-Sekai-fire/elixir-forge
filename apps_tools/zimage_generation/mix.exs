defmodule ZImageGeneration.MixProject do
  use Mix.Project

  def project do
    [
      app: :zimage_generation,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {ZImageGeneration.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Membrane multimedia framework
      {:membrane_core, "~> 1.0"},

      # Python integration
      {:pythonx, "~> 0.4.7"},
      {:jason, "~> 1.4.4" },

      # OpenTelemetry
      {:opentelemetry_api, "~> 1.3"},
      {:opentelemetry, "~> 1.7"},
      {:opentelemetry_exporter, "~> 1.10"}
    ]
  end
end