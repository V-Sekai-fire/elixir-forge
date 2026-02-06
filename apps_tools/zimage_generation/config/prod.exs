import Config
import_config "config.exs"

# Production-specific configuration
# Production logger level - minimal logging
config :logger,
  level: :error

# Production Pythonx configuration - no logging
config :pythonx,
  logger: false

# Production OpenTelemetry settings - no JSON export, only batch
config :opentelemetry,
  span_processors: [:batch]

# Production output configuration
config :zimage_generation, :output,
  base_dir: "/app/output",  # Production output directory
  create_timestamped: true

# Production-specific generation settings for quality
config :zimage_generation, :generation,
  width: 1024,    # Default HD resolution
  height: 1024,
  num_steps: 20,  # Higher quality generation
  guidance_scale: 3.5,  # Higher guidance for better results
  output_format: "png"  # Lossless format for quality