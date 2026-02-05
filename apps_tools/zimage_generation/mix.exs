defmodule ZImageGeneration.MixProject do
  use Mix.Project

  def project do
    [
      app: :zimage_generation,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
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
      {:membrane_core, "~> 1.2"},

      # Python integration
      {:pythonx, "~> 0.4.7"},
      {:jason, "~> 1.4.4" },

      # OpenTelemetry
      {:opentelemetry_api, "~> 1.3"},
      {:opentelemetry, "~> 1.7"},
      {:opentelemetry_exporter, "~> 1.10"},

      # Code quality
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  # Aliases
  defp aliases do
    [
      pipeline: &run_pipeline/1
    ]
  end

  defp run_pipeline(_) do
    Mix.shell().info("Starting ZImageGeneration Membrane pipeline...")

    # Compile and ensure the application is started so modules are available
    Mix.Task.run("compile")
    {:ok, _} = Application.ensure_all_started(:zimage_generation)

    # Example usage - replace with actual data as needed
    requests = [
      ZImageGeneration.Data.new([
        prompt: "a simple test image",
        width: 512,
        height: 512,
        seed: 42,
        num_steps: 4,
        guidance_scale: 0.0,
        output_format: "png"
      ])
    ]

    case ZImageGeneration.Pipeline.start(requests) do
      {:ok, pipeline} ->
        Mix.shell().info("Pipeline started successfully: #{inspect(pipeline)}")
      {:error, reason} ->
        Mix.shell().error("Failed to start pipeline: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end
end
