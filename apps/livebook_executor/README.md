# Livebook Executor Service

An Elixir service that can execute Livebook (`.livemd`) notebooks programmatically and perform Google searches.

## Features

- **Notebook Execution**: Execute Livebook notebooks with custom parameters
- **Google Search**: Perform web searches using Google Custom Search API
- **Zenoh Integration**: Service communication via Zenoh pub/sub
- **CLI Interface**: Command-line tools for direct usage
- **REST-like API**: JSON-based request/response protocol

## Installation

1. Add to your supervision tree or run as an escript
2. Set environment variables for Google Search:
   ```bash
   export GOOGLE_API_KEY="your_google_api_key"
   export GOOGLE_SEARCH_ENGINE_ID="your_search_engine_id"
   ```

## Usage

### CLI Commands

```bash
# Start the server
./livebook_executor

# Execute a notebook
./livebook_executor execute elixir/qwen3vl_inference.livemd --param model=qwen2-vl-7b

# Search Google
./livebook_executor search "elixir programming" --num-results 5

# List available notebooks
./livebook_executor list

# Show help
./livebook_executor help
```

### Zenoh API

Send JSON requests to the `livebook_executor/requests` topic:

```json
{
  "action": "execute_notebook",
  "notebook_path": "elixir/qwen3vl_inference.livemd",
  "params": {"model": "qwen2-vl-7b"}
}
```

```json
{
  "action": "search_google",
  "query": "elixir programming",
  "options": {"num_results": 5}
}
```

```json
{
  "action": "list_notebooks"
}
```

Receive responses on the `livebook_executor/results` topic:

```json
{
  "action": "search_google",
  "result": {
    "query": "elixir programming",
    "total_results": "12300000",
    "search_time": 0.45,
    "results": [
      {
        "title": "Elixir Programming Language",
        "link": "https://elixir-lang.org/",
        "snippet": "Elixir is a dynamic, functional language designed for building scalable and maintainable applications...",
        "display_link": "elixir-lang.org"
      }
    ]
  },
  "timestamp": "2024-01-16T20:40:35Z"
}
```

### Programmatic API

```elixir
# Start the service
{:ok, _} = Application.ensure_all_started(:livebook_executor)

# Execute a notebook
{:ok, result} = LivebookExecutor.Server.execute_notebook("elixir/qwen3vl_inference.livemd", %{"model" => "qwen2-vl-7b"})

# Search Google
{:ok, results} = LivebookExecutor.Server.search_google("elixir programming", %{"num_results" => 5})

# List notebooks
{:ok, notebooks} = LivebookExecutor.Server.list_notebooks()
```

## Dependencies

- `zenohex` - Zenoh communication
- `jason` - JSON encoding/decoding
- `req` - HTTP client for Google Search API
- `livebook` - Livebook runtime (for future notebook execution)

## Google Custom Search Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable the Custom Search JSON API
4. Create credentials (API Key)
5. Go to [Custom Search Engine](https://cse.google.com/)
6. Create a new search engine
7. Get the Search Engine ID
8. Set environment variables:
   ```bash
   export GOOGLE_API_KEY="your_api_key_here"
   export GOOGLE_SEARCH_ENGINE_ID="your_search_engine_id_here"
   ```

## Architecture

The service consists of:

- **CLI Module**: Command-line interface for direct usage
- **Server Module**: GenServer handling requests and Zenoh communication
- **Application Module**: OTP application setup

The service integrates with the existing Zenoh-based service architecture used by other forge components.
