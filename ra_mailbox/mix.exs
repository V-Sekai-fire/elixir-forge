defmodule RAMailbox.MixProject do
  use Mix.Project

  def project do
    [
      app: :ra_mailbox,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {RAMailbox.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:zenohex, "~> 0.7.2"},
      {:ra, "~> 2.7.0"},
      {:jason, "~> 1.4"}
    ]
  end
end
