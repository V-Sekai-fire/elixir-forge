defmodule LivebookExecutor.MixProject do
  use Mix.Project

  def project do
    [
      app: :livebook_executor,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: escript()
    ]
  end

  def escript do
    [main_module: LivebookExecutor.CLI]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {LivebookExecutor.Application, []},
      applications: [:zenohex]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:zenohex, "~> 0.7.2"},
      {:rustler, ">= 0.0.0", optional: true},
      {:jason, "~> 1.4.4"},
      {:req, "~> 0.4.0"},
      {:credo, "~> 1.7", only: [:dev], runtime: false}
    ]
  end
end
