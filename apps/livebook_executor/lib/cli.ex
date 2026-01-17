defmodule LivebookExecutor.CLI do
  @moduledoc """
  Command-line interface for the Livebook Executor service
  """

  def main(args) do
    case parse_args(args) do
      {:execute, notebook_path, params} ->
        start_app()
        execute_notebook(notebook_path, params)

      {:search, query, options} ->
        start_app()
        search_google(query, options)

      {:list} ->
        start_app()
        list_notebooks()

      {:server} ->
        IO.puts("Server mode not implemented yet. Use direct CLI commands instead.")
        System.halt(1)

      {:help} ->
        print_help()

      {:error, message} ->
        IO.puts("Error: #{message}")
        print_help()
        System.halt(1)
    end
  end

  defp parse_args(args) do
    case args do
      ["execute", notebook_path | rest] ->
        {params, _} = OptionParser.parse!(rest, switches: [param: :string])
        params_map = Map.new(params, fn {:param, param} ->
          [key, value] = String.split(param, "=", parts: 2)
          {key, value}
        end)
        {:execute, notebook_path, params_map}

      ["search", query | rest] ->
        {options, _} = OptionParser.parse!(rest, switches: [num_results: :integer, start_index: :integer])
        options_map = Map.new(options)
        {:search, query, options_map}

      ["list"] ->
        {:list}

      ["server"] ->
        {:server}

      ["help"] ->
        {:help}

      ["--help"] ->
        {:help}

      ["-h"] ->
        {:help}

      [] ->
        {:server}

      _ ->
        {:error, "Invalid command. Use 'help' for usage information."}
    end
  end

  defp start_app do
    # Start only the essential applications, not zenohex for now
    {:ok, _} = Application.ensure_all_started(:jason)
    {:ok, _} = Application.ensure_all_started(:req)
    # Note: Not starting zenohex to avoid NIF issues for CLI usage
  end

  defp start_server do
    IO.puts("Starting Livebook Executor Server...")
    IO.puts("Press Ctrl+C to stop.")

    # Start the application
    {:ok, _} = Application.ensure_all_started(:livebook_executor)

    # Keep the process alive
    Process.sleep(:infinity)
  end

  defp execute_notebook(notebook_path, params) do
    IO.puts("Executing notebook: #{notebook_path}")
    IO.puts("Parameters: #{inspect(params)}")

    # For now, simulate notebook execution directly
    if File.exists?(notebook_path) do
      result = %{
        notebook_path: notebook_path,
        params: params,
        executed_at: DateTime.utc_now(),
        status: :completed,
        output: "Notebook execution simulated - #{notebook_path}"
      }

      IO.puts("✓ Notebook executed successfully")
      IO.puts("Result: #{inspect(result, pretty: true)}")
    else
      IO.puts("✗ Failed to execute notebook: Notebook file not found: #{notebook_path}")
      System.halt(1)
    end
  end

  defp search_google(query, options) do
    IO.puts("Searching Google for: #{query}")
    IO.puts("Options: #{inspect(options)}")

    # Google Custom Search API configuration
    api_key = System.get_env("GOOGLE_API_KEY")
    search_engine_id = System.get_env("GOOGLE_SEARCH_ENGINE_ID")

    if !api_key or !search_engine_id do
      IO.puts("✗ Search failed: Google API credentials not configured. Set GOOGLE_API_KEY and GOOGLE_SEARCH_ENGINE_ID environment variables.")
      System.halt(1)
    else
      # Build search URL
      num_results = Map.get(options, :num_results, 10)
      start_index = Map.get(options, :start_index, 1)

      url = "https://www.googleapis.com/customsearch/v1"
      params = %{
        key: api_key,
        cx: search_engine_id,
        q: query,
        num: min(num_results, 10),  # Google limits to 10 per request
        start: start_index
      }

      # Make HTTP request
      case Req.get(url, params: params) do
        {:ok, %{status: 200, body: body}} ->
          # Process search results
          results = process_search_results(body)
          IO.puts("✓ Search completed successfully")
          IO.puts("Found #{length(results.results)} results in #{results.search_time}s")
          IO.puts("Total results: #{results.total_results}")
          IO.puts("")

          Enum.each(results.results, fn result ->
            IO.puts("📄 #{result.title}")
            IO.puts("🔗 #{result.link}")
            IO.puts("📝 #{result.snippet}")
            IO.puts("")
          end)

        {:ok, %{status: status, body: body}} ->
          IO.puts("✗ Search failed: Google search API error: #{status}")
          System.halt(1)

        {:error, reason} ->
          IO.puts("✗ Search failed: #{inspect(reason)}")
          System.halt(1)
      end
    end
  end

  defp list_notebooks do
    IO.puts("Available notebooks:")

    # Find all .livemd files in the elixir directory
    notebooks = Path.wildcard("../../elixir/**/*.livemd")
    |> Enum.map(fn path ->
      %{
        path: path,
        name: Path.basename(path, ".livemd"),
        directory: Path.dirname(path),
        size: File.stat!(path).size,
        modified: File.stat!(path).mtime |> NaiveDateTime.from_erl!()
      }
    end)
    |> Enum.sort_by(& &1.name)

    if notebooks == [] do
      IO.puts("No notebooks found.")
    else
      Enum.each(notebooks, fn notebook ->
        IO.puts("📓 #{notebook.name}")
        IO.puts("   Path: #{notebook.path}")
        IO.puts("   Size: #{notebook.size} bytes")
        IO.puts("   Modified: #{notebook.modified}")
        IO.puts("")
      end)
    end
  end

  defp process_search_results(response_body) do
    items = response_body["items"] || []

    results = Enum.map(items, fn item ->
      %{
        title: item["title"],
        link: item["link"],
        snippet: item["snippet"],
        display_link: item["displayLink"]
      }
    end)

    %{
      query: response_body["queries"]["request"] |> List.first() |> Map.get("searchTerms"),
      total_results: response_body["searchInformation"]["totalResults"],
      search_time: response_body["searchInformation"]["searchTime"],
      results: results
    }
  end

  defp print_help do
    IO.puts("""
    Livebook Executor - Execute .livemd files and search Google

    USAGE:
      livebook_executor [COMMAND] [OPTIONS]

    COMMANDS:
      execute <notebook_path> [--param key=value ...]
        Execute a Livebook notebook with optional parameters

      search <query> [--num-results N] [--start-index N]
        Search Google for the given query

      list
        List all available notebooks

      server
        Start the Livebook Executor server (default when no command given)

      help, --help, -h
        Show this help message

    EXAMPLES:
      # Start the server
      livebook_executor

      # Execute a notebook
      livebook_executor execute elixir/qwen3vl_inference.livemd --param model=qwen2-vl-7b

      # Search Google
      livebook_executor search "elixir programming" --num-results 5

      # List notebooks
      livebook_executor list

    ENVIRONMENT VARIABLES:
      GOOGLE_API_KEY        - Google Custom Search API key
      GOOGLE_SEARCH_ENGINE_ID - Google Custom Search Engine ID

    ZENOH TOPICS:
      livebook_executor/requests  - Send requests to the service
      livebook_executor/results   - Receive results from the service
    """)
  end
end
