import Config

# Membrane configuration
config :membrane_core,
  membrane_log: :info

# Python environment configuration for Z-Image generation (Pythonx application style)
config :pythonx, :uv_init,
  pyproject_toml: """
  [project]
  name = "zimage-generation"
  version = "0.0.0"
  requires-python = "==3.10.*"
  dependencies = [
    "diffusers @ git+https://github.com/huggingface/diffusers",
    "transformers",
    "accelerate",
    "pillow",
    "torch",
    "torchvision",
    "numpy",
    "huggingface-hub",
    "gitpython",
  ]

  [tool.uv.sources]
  torch = { index = "pytorch-cu118" }
  torchvision = { index = "pytorch-cu118" }

  [[tool.uv.index]]
  name = "pytorch-cu118"
  url = "https://download.pytorch.org/whl/cu118"
  explicit = true
  """

# OpenTelemetry configuration
config :opentelemetry_api,
  processors: [
    opentelemetry_exporter: %{}
  ],
  resource: %{
    "service.name" => "zimage_generation",
    "service.version" => "0.1.0"
  }

config :opentelemetry,
  span_processor: :batch,
  traces_exporter: :none,
  metrics_exporter: :none,
  logs_exporter: :none