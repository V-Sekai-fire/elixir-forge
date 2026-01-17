defmodule LivebookExecutor.Server do
  @moduledoc """
  Livebook Executor Server - executes .livemd files and provides Google search functionality
  """
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    Logger.info("Starting Livebook Executor Server")

    case start_zenoh_session() do
      {:ok, session_state} ->
        Logger.info("Zenoh session started successfully")
        {:ok, Map.merge(session_state, %{notebooks: %{}})}

      {:error, reason} ->
        Logger.error("Failed to start Zenoh session: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  def execute_notebook(notebook_path, params \\ %{}) do
    GenServer.call(__MODULE__, {:execute_notebook, notebook_path, params})
  end

  def search_google(query, options \\ %{}) do
    GenServer.call(__MODULE__, {:search_google, query, options})
  end

  def list_notebooks do
    GenServer.call(__MODULE__, :list_notebooks)
  end

  # GenServer callbacks

  def handle_call({:execute_notebook, notebook_path, params}, _from, state) do
    result = execute_notebook_sync(notebook_path, params)
    {:reply, result, state}
  end

  def handle_call({:search_google, query, options}, _from, state) do
    result = perform_google_search(query, options)
    {:reply, result, state}
  end

  def handle_call(:list_notebooks, _from, state) do
    notebooks = find_notebooks()
    {:reply, {:ok, notebooks}, state}
  end

  def handle_info(%Zenohex.Sample{} = sample, state) do
    handle_zenoh_request(sample.payload, state.session_id)
    {:noreply, state}
  end

  # Private functions

  defp start_zenoh_session do
    try do
      # Start Zenoh session
      {:ok, session_id} = Zenohex.Session.open()

      # Declare publisher for results
      {:ok, _pub} = Zenohex.Session.declare_publisher(session_id, "livebook_executor/results")

      # Declare subscriber for requests
      {:ok, _sub} = Zenohex.Session.declare_subscriber(session_id, "livebook_executor/requests", self())

      {:ok, %{session_id: session_id}}
    rescue
      e ->
        Logger.error("Exception starting Zenoh session: #{inspect(e)}")
        {:error, e}
    end
  end

  defp handle_zenoh_request(message, session_id) do
    try do
      case Jason.decode(message) do
        {:ok, %{"action" => "execute_notebook", "notebook_path" => path, "params" => params}} ->
          result = execute_notebook_sync(path, params || %{})
          publish_result("execute_notebook", result, session_id)

        {:ok, %{"action" => "search_google", "query" => query, "options" => options}} ->
          result = perform_google_search(query, options || %{})
          publish_result("search_google", result, session_id)

        {:ok, %{"action" => "list_notebooks"}} ->
          notebooks = find_notebooks()
          publish_result("list_notebooks", {:ok, notebooks}, session_id)

        _ ->
          Logger.warning("Unknown Zenoh request: #{inspect(message)}")
      end
    rescue
      e ->
        Logger.error("Error handling Zenoh request: #{inspect(e)}")
        publish_result("error", {:error, "Failed to process request: #{inspect(e)}"}, session_id)
    end
  end

  defp publish_result(action, result, session_id) do
    response = %{
      action: action,
      result: result,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    case Jason.encode(response) do
      {:ok, json} ->
        # Publish to Zenoh topic using the session
        case Zenohex.Session.put(session_id, "livebook_executor/results", json) do
          :ok -> :ok
          error -> Logger.error("Failed to publish result: #{inspect(error)}")
        end

      {:error, reason} ->
        Logger.error("Failed to encode result: #{inspect(reason)}")
    end
  end

  defp execute_notebook_sync(notebook_path, params) do
    try do
      Logger.info("Executing notebook: #{notebook_path}")

      # Check if file exists
      unless File.exists?(notebook_path) do
        {:error, "Notebook file not found: #{notebook_path}"}
      else
        # For now, we'll simulate notebook execution
        # In a real implementation, you'd use Livebook's runtime API
        # to execute the notebook with the given parameters

        result = %{
          notebook_path: notebook_path,
          params: params,
          executed_at: DateTime.utc_now(),
          status: :completed,
          output: "Notebook execution simulated - #{notebook_path}"
        }

        Logger.info("Notebook execution completed: #{notebook_path}")
        {:ok, result}
      end
    rescue
      e ->
        Logger.error("Error executing notebook #{notebook_path}: #{inspect(e)}")
        {:error, "Failed to execute notebook: #{inspect(e)}"}
    end
  end

  defp perform_google_search(query, options) do
    try do
      Logger.info("Performing Google search: #{query}")

      # Google Custom Search API configuration
      api_key = System.get_env("GOOGLE_API_KEY")
      search_engine_id = System.get_env("GOOGLE_SEARCH_ENGINE_ID")

      if !api_key or !search_engine_id do
        {:error, "Google API credentials not configured. Set GOOGLE_API_KEY and GOOGLE_SEARCH_ENGINE_ID environment variables."}
      else
        # Build search URL
        num_results = Map.get(options, "num_results", 10)
        start_index = Map.get(options, "start_index", 1)

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
            {:ok, results}

          {:ok, %{status: status, body: body}} ->
            Logger.error("Google search API error: #{status} - #{inspect(body)}")
            {:error, "Google search failed with status #{status}"}

          {:error, reason} ->
            Logger.error("Google search request failed: #{inspect(reason)}")
            {:error, "Failed to perform Google search: #{inspect(reason)}"}
        end
      end
    rescue
      e ->
        Logger.error("Error performing Google search: #{inspect(e)}")
        {:error, "Failed to perform Google search: #{inspect(e)}"}
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

  defp find_notebooks do
    # Find all .livemd files in the elixir directory
    Path.wildcard("elixir/**/*.livemd")
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
  end
end
