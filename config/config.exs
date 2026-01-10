import Config

# Configure the main application
config :livebook_nx,
  ecto_repos: [LivebookNx.Repo]

# Configure Oban
config :livebook_nx, Oban,
  repo: LivebookNx.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 5, ml: 8]

# Database (development defaults - production uses environment variables)
config :livebook_nx, LivebookNx.Repo,
  database: System.get_env("DATABASE_NAME", "livebook_nx_dev"),
  username: System.get_env("DATABASE_USER", "root"),
  password: System.get_env("DATABASE_PASSWORD", "secure_password_123"),
  hostname: System.get_env("DATABASE_HOST", "localhost"),
  port: String.to_integer(System.get_env("DATABASE_PORT", "26257")),
  # Use SSL in production, disable for local insecure CockroachDB
  ssl: if(System.get_env("COCKROACH_INSECURE", "true") == "true", do: false, else: [
    cacertfile: System.get_env("DB_CA_CERT", "cockroach-certs/ca.crt"),
    certfile: System.get_env("DB_CLIENT_CERT", "cockroach-certs/client.root.crt"),
    keyfile: System.get_env("DB_CLIENT_KEY", "cockroach-certs/client.root.key")
  ]),
  migration_lock: nil

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
url = "https://download.pytorch.org/whl/cu118"
explicit = true
"""
