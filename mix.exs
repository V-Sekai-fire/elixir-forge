defmodule Forge.MixProject do
  use Mix.Project

  def project do
    [
      app: :forge,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      releases: releases(),
      deps: deps()
    ]
  end

  def releases do
    [
      forge: [
        include_executables_for: [:unix, :windows],
        include_erts: true,
        applications: [
          forge: :permanent,
          runtime_tools: :permanent
        ],
        steps: [:assemble, :tar],
        strip_beams: Mix.env() == :prod
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Forge.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nx, "~> 0.7"},
      # {:exla, "~> 0.7"},  # Skip EXLA on Windows
      # {:torchx, "~> 0.7"},  # Skip Torchx, using Python instead
      {:pythonx, "~> 0.4"},
      {:jason, "~> 1.4"},
      {:req, "~> 0.5"},
      {:oban, "~> 2.17"},
      {:ecto_sql, "~> 3.10"},
      {:ecto_sqlite3, "~> 0.12"},  # SQLite for simple embedded database
      {:opentelemetry_api, "~> 1.3"},
      {:opentelemetry, "~> 1.3"},
      {:opentelemetry_exporter, "~> 1.0"},
      {:x509, "~> 0.8"},  # For certificate generation
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}  # Code quality checker
    ]
  end
end
