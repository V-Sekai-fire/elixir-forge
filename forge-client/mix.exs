defmodule ForgeClient.MixProject do
  use Mix.Project

  def project do
    [
      app: :forge_client,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: escript()
    ]
  end

  def escript do
    [main_module: ForgeClient.CLI]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ForgeClient.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:zenohex, "~> 0.7.2"},
      {:jason, "~> 1.4.4"},
      {:flatbuffer, "~> 0.3.1"}
    ]
  end
end
