defmodule SpanCollector do
  @moduledoc """
  Wrapper around OpenTelemetry.Tracer API for convenience.
  Uses the official OpenTelemetry library from hex.pm instead of custom implementation.
  """
  require OpenTelemetry.Tracer

  # Extract exit code from SystemExit exception
  defp extract_exit_code(_value, python_globals) do
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

  def display_trace(_output_dir \\ nil) do
    # Display basic trace information
    IO.puts("")
    IO.puts("=== OpenTelemetry Trace ===")
    IO.puts("")
    IO.puts("Note: Use OpenTelemetry exporters (OTLP, Jaeger, etc.) to view traces.")
    IO.puts("For JSON export, configure opentelemetry_exporter_otlp or similar.")
    IO.puts("")
  end
end

# ============================================================================
# HUGGING FACE DOWNLOADER
# ============================================================================

defmodule HuggingFaceDownloader do
  @moduledoc """
  Downloads model repositories from Hugging Face.
  """
  @compile {:no_warn_undefined, [Req]}
  @base_url "https://huggingface.co"
  @api_base "https://huggingface.co/api"

  def download_repo(repo_id, local_dir, repo_name \\ "model", use_otel \\ false) do
    if use_otel do
      SpanCollector.track_span("download_repo", fn ->
        IO.puts("Downloading #{repo_name}...")
      end, [{"download.repo_name", repo_name}, {"download.repo_id", repo_id}])
    else
      IO.puts("Downloading #{repo_name}...")
    end

    File.mkdir_p!(local_dir)

    case get_file_tree(repo_id) do
      {:ok, files} ->
        files_list = Map.to_list(files)
        total = length(files_list)
        if use_otel do
          SpanCollector.track_span("download_files", fn ->
            IO.puts("Found #{total} files to download")
          end, [{"download.file_count", total}])
        else
          IO.puts("Found #{total} files to download")
        end

        files_list
        |> Enum.with_index(1)
        |> Enum.each(fn {{path, info}, index} ->
          download_file(repo_id, path, local_dir, info, index, total, use_otel)
        end)

        if use_otel do
          SpanCollector.track_span("download_complete", fn ->
            IO.puts("[OK] #{repo_name} downloaded successfully")
          end, [{"download.repo_name", repo_name}, {"download.status", "completed"}])
        else
          IO.puts("[OK] #{repo_name} downloaded successfully")
        end
        {:ok, local_dir}

      {:error, reason} ->
        if use_otel do
          SpanCollector.track_span("download_failed", fn ->
            IO.puts("[ERROR] #{repo_name} download failed: #{inspect(reason)}")
          end, [{"download.repo_name", repo_name}, {"download.status", "failed"}, {"error.reason", inspect(reason)}])
        else
          IO.puts("[ERROR] #{repo_name} download failed: #{inspect(reason)}")
        end
        {:error, reason}
    end
  end

  defp get_file_tree(repo_id, revision \\ "main") do
    case get_files_recursive(repo_id, revision, "") do
      {:ok, files} ->
        file_map =
          files
          |> Enum.map(fn file -> {file["path"], file} end)
          |> Map.new()
        {:ok, file_map}
      error -> error
    end
  end

  defp get_files_recursive(repo_id, revision, path) do
    url = if path == "" do
      "#{@api_base}/models/#{repo_id}/tree/#{revision}"
    else
      "#{@api_base}/models/#{repo_id}/tree/#{revision}/#{path}"
    end

    try do
      response = Req.get(url)
      items = case response do
        {:ok, %{status: 200, body: body}} when is_list(body) -> body
        %{status: 200, body: body} when is_list(body) -> body
        {:ok, %{status: status}} -> raise "API returned status #{status}"
        %{status: status} -> raise "API returned status #{status}"
        {:error, reason} -> raise inspect(reason)
        other -> raise "Unexpected response: #{inspect(other)}"
      end

      files = Enum.filter(items, &(&1["type"] == "file"))
      dirs = Enum.filter(items, &(&1["type"] == "directory"))

      subdir_files =
        dirs
        |> Enum.flat_map(fn dir ->
          case get_files_recursive(repo_id, revision, dir["path"]) do
            {:ok, subfiles} -> subfiles
            _ -> []
          end
        end)

      {:ok, files ++ subdir_files}
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  defp download_file(repo_id, path, local_dir, info, current, total, use_otel) do
    url = "#{@base_url}/#{repo_id}/resolve/main/#{path}"
    local_path = Path.join(local_dir, path)
    file_size = info["size"] || 0
    size_mb = if file_size > 0, do: Float.round(file_size / 1024 / 1024, 1), else: 0
    filename = Path.basename(path)
    IO.write("\r  [#{current}/#{total}] Downloading: #{filename} (#{size_mb} MB)")

    if File.exists?(local_path) do
      IO.write("\r  [#{current}/#{total}] Skipped (exists): #{filename}")
    else
      local_path
      |> Path.dirname()
      |> File.mkdir_p!()

      result = Req.get(url,
        into: File.stream!(local_path, [], 65536),
        retry: :transient,
        max_redirects: 10
      )

      case result do
        {:ok, %{status: 200}} -> IO.write("\r  [#{current}/#{total}] ✓ #{filename}")
        %{status: 200} -> IO.write("\r  [#{current}/#{total}] ✓ #{filename}")
        {:ok, %{status: status}} ->
          if use_otel do
            SpanCollector.track_span("download_file_failed", fn ->
              IO.puts("\n[WARN] Failed to download file: #{path} (status: #{status})")
            end, [{"download.file_path", path}, {"download.status_code", status}])
          else
            IO.puts("\n[WARN] Failed to download file: #{path} (status: #{status})")
          end
        %{status: status} ->
          if use_otel do
            SpanCollector.track_span("download_file_failed", fn ->
              IO.puts("\n[WARN] Failed to download file: #{path} (status: #{status})")
            end, [{"download.file_path", path}, {"download.status_code", status}])
          else
            IO.puts("\n[WARN] Failed to download file: #{path} (status: #{status})")
          end
        {:error, reason} ->
          if use_otel do
            SpanCollector.track_span("download_file_failed", fn ->
              IO.puts("\n[WARN] Failed to download file: #{path} (#{inspect(reason)})")
            end, [{"download.file_path", path}, {"error.reason", inspect(reason)}])
          else
            IO.puts("\n[WARN] Failed to download file: #{path} (#{inspect(reason)})")
          end
      end
    end
  end
end
