#!/usr/bin/env elixir

# Setup script for Livebook Nx Qwen3-VL project

IO.puts("Setting up Livebook Nx with Qwen3-VL...")

# Install Elixir dependencies
IO.puts("Installing Elixir dependencies...")
System.cmd("mix", ["deps.get"])

# Python environment is configured in config/config.exs
IO.puts("Python environment is configured in config/config.exs")
IO.puts("Run 'mix compile' to initialize Python environment.")
IO.puts("Then, run 'mix qwen3vl path/to/image.jpg \"Describe this image\"' to test Qwen3-VL inference.")

IO.puts("Setup complete!")
