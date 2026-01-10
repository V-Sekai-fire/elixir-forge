defmodule SpanCollector do
  @moduledoc """
  Wrapper around OpenTelemetry.Tracer API for convenience.
  Uses the official OpenTelemetry library from hex.pm instead of custom implementation.
  """
  require OpenTelemetry.Tracer

  # Extract exit code from SystemExit exception
  defp extract_exit_code(value, python_globals) do
    try do
      {code, _} = Pythonx.eval("_elixir_value.__int__()", python_globals)
      code
    rescue
      _ ->
        # Try to get exit code from args
        try do
          {args, _} = Pythonx.eval("_elixir_value.args", python_globals)
          case args do
            [code] when is_integer(code) -> code
            _ -> 0
          end
        rescue
          _ -> 0
        end
    end
  end

  def track_span(name, fun, attrs \\ []) do
    OpenTelemetry.Tracer.with_span name do
      # Set attributes on the current span
      Enum.each(attrs, fn {key, value} ->
        OpenTelemetry.Tracer.set_attribute(key, value)
      end)

      try do
        result = fun.()
        OpenTelemetry.Tracer.set_status(:ok)
        result
      rescue
        e ->
          handle_span_exception(e)
      end
    end
  end

  # Extracted helper function to handle different exception types
  defp handle_span_exception(e) do
    case e do
      %Pythonx.Error{type: type, value: value} ->
        handle_python_exception(type, value, e)
      _ ->
        handle_elixir_exception(e)
    end
  end

  # Handle Python-specific exceptions
  defp handle_python_exception(type, value, original_exception) do
    try do
      python_globals = %{"_elixir_type" => type, "_elixir_value" => value}
      {type_name, _} = Pythonx.eval("_elixir_type.__name__", python_globals)

      if type_name == "SystemExit" do
        handle_system_exit(value, python_globals, original_exception)
      else
        handle_other_python_exception(original_exception, type_name)
      end
    rescue
      _ ->
        handle_unknown_python_exception(original_exception)
    end
  end

  # Handle SystemExit exceptions from Python
  defp handle_system_exit(value, python_globals, original_exception) do
    exit_code = extract_exit_code(value, python_globals)

    if exit_code == 0 do
      OpenTelemetry.Tracer.set_status(:ok)
      :ok
    else
      OpenTelemetry.Tracer.record_exception(original_exception, [])
      OpenTelemetry.Tracer.set_status(:error, "SystemExit(#{exit_code})")
      raise original_exception
    end
  end

  # Handle other Python exceptions
  defp handle_other_python_exception(original_exception, type_name) do
    OpenTelemetry.Tracer.record_exception(original_exception, [])
    try do
      OpenTelemetry.Tracer.set_status(:error, Exception.message(original_exception))
    rescue
      _ -> OpenTelemetry.Tracer.set_status(:error, "Python exception: #{inspect(type_name)}")
    end
    raise original_exception
  end

  # Handle unknown Python exceptions
  defp handle_unknown_python_exception(original_exception) do
    OpenTelemetry.Tracer.record_exception(original_exception, [])
    try do
      OpenTelemetry.Tracer.set_status(:error, Exception.message(original_exception))
    rescue
      _ -> OpenTelemetry.Tracer.set_status(:error, "Python exception")
    end

      raise original_exception
  end

  # Handle regular Elixir exceptions
  defp handle_elixir_exception(original_exception) do
    OpenTelemetry.Tracer.record_exception(original_exception, [])
    try do
      OpenTelemetry.Tracer.set_status(:error, Exception.message(original_exception))
    rescue
      _ -> OpenTelemetry.Tracer.set_status(:error, inspect(original_exception))
    end
    raise original_exception
  end

  def add_span_attribute(key, value) do
    OpenTelemetry.Tracer.set_attribute(key, value)
  end

  def get_trace_context do
    # Get current trace context for propagation to Python
    # Returns TRACEPARENT format string for W3C trace context propagation
    try do
      # Get current span context
      span_ctx = OpenTelemetry.Tracer.current_span_ctx()

      if span_ctx do
        # Extract trace_id and span_id from span context
        # OpenTelemetry span context is a tuple/record with trace_id and span_id
        # Try to extract using pattern matching or element access
        trace_id = try do
          :erlang.element(2, span_ctx)  # trace_id is typically at position 2
        rescue
          _ -> nil
        end

        span_id = try do
          :erlang.element(3, span_ctx)  # span_id is typically at position 3
        rescue
          _ -> nil
        end

        if trace_id && span_id do
          # Format as TRACEPARENT (version-trace_id-span_id-trace_flags)
          # version = 00, trace_id = 32 hex chars, span_id = 16 hex chars, trace_flags = 2 hex chars
          trace_id_hex = trace_id |> Integer.to_string(16) |> String.pad_leading(32, "0")
          span_id_hex = span_id |> Integer.to_string(16) |> String.pad_leading(16, "0")
          trace_flags_hex = "01"  # Default: sampled

          "00-#{trace_id_hex}-#{span_id_hex}-#{trace_flags_hex}"
        else
          nil
        end
      else
        nil
      end
    rescue
      _ -> nil
    end
  end

  def record_metric(_name, _value, _unit \\ nil) do
    # Use OpenTelemetry Metrics API when available
    # For now, we'll need to use a metrics exporter or custom collection
    # This is a placeholder - proper implementation would use OpenTelemetry.Metrics
    :ok
  end

  def display_trace(output_dir \\ nil) do
    # Export JSON trace data if available
    try do
      if Process.whereis(OtelJsonExporter) do
        OtelJsonExporter.export_json(output_dir)
      else
        # Fallback if exporter not available
        IO.puts("")
        IO.puts("=== OpenTelemetry Trace ===")
        IO.puts("")
        IO.puts("Note: Use OpenTelemetry exporters (OTLP, Jaeger, etc.) to view traces.")
        IO.puts("For JSON export, configure opentelemetry_exporter_otlp or similar.")
        IO.puts("")
      end
    rescue
      e ->
        IO.puts("")
        IO.puts("=== OpenTelemetry Trace ===")
        IO.puts("")
        IO.puts("Error exporting trace: #{inspect(e)}")
        IO.puts("")
    end
  end
end
