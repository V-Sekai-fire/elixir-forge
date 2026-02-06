import Config
import_config "config.exs"

# Test-specific configuration
# Disable output during tests to reduce noise and file creation
config :zimage_generation, :output,
  base_dir: "test_output",
  create_timestamped: false

# Disable OpenTelemetry span processors in tests
config :opentelemetry,
  span_processors: []

# Test-specific logger level
config :logger,
  level: :warn

# Disable Pythonx logging in tests
config :pythonx,
  logger: false

# Test-specific settings for faster/smaller image generation
config :zimage_generation, :generation,
  width: 256,
  height: 256,
  num_steps: 2,
  guidance_scale: 0.0,
  seed: 1,
  force_cpu: true  # Force CPU for consistent test results

# Additional test overrides
config :zimage_generation, :test,
  force_cpu: true  # Ensure GPU is not used in tests
