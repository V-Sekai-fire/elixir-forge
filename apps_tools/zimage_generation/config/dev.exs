import Config
import_config "config.exs"

# Development-specific configuration
# Logger level for dev environment
config :logger,
  level: :debug

# Pythonx logging in dev mode for debugging
config :pythonx,
  logger: true

# Development OpenTelemetry settings - enable JSON export for debugging
config :opentelemetry,
  span_processors: [:batch, OtelJsonExporter]

# Development-specific output settings
config :zimage_generation, :output,
  base_dir: "output",
  create_timestamped: true