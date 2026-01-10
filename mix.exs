defmodule LivebookNx.MixProject do
  use Mix.Project

  def project do
    [
      app: :livebook_nx,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      releases: releases(),
      deps: deps()
    ]
  end

  def releases do
    [
      livebook_nx: [
        include_executables_for: [:unix, :windows],
        include_erts: true,
        applications: [
          livebook_nx: :permanent,
          runtime_tools: :permanent
        ],
        steps: [:assemble, :tar],
        strip_beams: Mix.env() == :prod,
        # Include CockroachDB binary and certificates
        extra_steps: [
          &include_cockroachdb/1,
          &include_certificates/1
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {LivebookNx.Application, []}
    ]
  end

  # Include CockroachDB binary in the release
  defp include_cockroachdb(release) do
    cockroach_path = "tools/cockroach-v22.1.22.windows-6.2-amd64/cockroach.exe"
    release_path = Path.join([release.path, "cockroach.exe"])

    if File.exists?(cockroach_path) do
      File.cp!(cockroach_path, release_path)
      Mix.shell().info("Included CockroachDB binary in release")
    else
      Mix.shell().error("CockroachDB binary not found at #{cockroach_path}")
    end

    release
  end

  # Include certificates in the release
  defp include_certificates(release) do
    certs_dir = "cockroach-certs"
    release_certs_dir = Path.join(release.path, "cockroach-certs")

    if File.exists?(certs_dir) do
      File.mkdir_p!(release_certs_dir)
      File.cp_r!(certs_dir, release_certs_dir)
      Mix.shell().info("Included certificates in release")
    else
      Mix.shell().error("Certificates directory not found at #{certs_dir}")
    end

    release
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
      {:postgrex, "~> 0.17"},  # For CockroachDB compatibility
      {:opentelemetry_api, "~> 1.3"},
      {:opentelemetry, "~> 1.3"},
      {:opentelemetry_exporter, "~> 1.0"},
      {:x509, "~> 0.8"},  # For certificate generation
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}  # Code quality checker
    ]
  end
end
