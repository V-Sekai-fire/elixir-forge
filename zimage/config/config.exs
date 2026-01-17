import Config

# Configure OpenTelemetry for console-only logging
config :opentelemetry, :span_processor, :batch
config :opentelemetry, :traces_exporter, :none
config :opentelemetry, :metrics_exporter, :none
config :opentelemetry, :logs_exporter, :none

# Configure logger
config :logger, level: :info