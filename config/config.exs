import Config

# Configure Oban
config :livebook_nx, Oban,
  repo: LivebookNx.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 10, zimage: 2]

# Database
config :livebook_nx, LivebookNx.Repo,
  database: "livebook_nx_dev",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: 5432

# OpenTelemetry
config :opentelemetry,
  span_processor: :batch,
  traces_exporter: :none,
  metrics_exporter: :none,
  logs_exporter: :none

# Logger
config :logger, level: :info

# Pythonx configuration for Qwen3-VL and Z-Image-Turbo
config :pythonx, :uv_init,
  pyproject_toml: """
[project]
name = "livebook-nx-inference"
version = "0.0.0"
requires-python = "==3.10.*"
dependencies = [
  "transformers",
  "accelerate",
  "pillow",
  "torch>=2.0.0,<2.5.0",
  "torchvision>=0.15.0,<0.20.0",
  "numpy",
  "huggingface-hub",
  "bitsandbytes",
  "diffusers @ git+https://github.com/huggingface/diffusers",
]

[tool.uv.sources]
torch = { index = "pytorch-cu118" }
torchvision = { index = "pytorch-cu118" }

[[tool.uv.index]]
name = "pytorch-cu118"

[tool.uv.sources]
torch = { index = "pytorch-cu118" }
torchvision = { index = "pytorch-cu118" }

[[tool.uv.index]]
name = "pytorch-cu118"
url = "https://download.pytorch.org/whl/cu118"
explicit = true
"""
