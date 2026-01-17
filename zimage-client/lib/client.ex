defmodule ZimageClient.Client do
  @moduledoc """
  Zenoh client for requesting Z-Image generation.

  This module provides functions to send image generation requests
  to Zimage services via Zenoh.
  """

  use GenServer
  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Generate an image using the Zenoh service.

  ## Parameters
  - prompt: Text description of the image
  - opts: Keyword list of options

  ## Options
  - timeout: Request timeout in milliseconds (default: 30000)
  - width: Image width (default: 1024)
  - height: Image height (default: 1024)
  - seed: Random seed (default: 0)
  - num_steps: Number of inference steps (default: 4)
  - guidance_scale: Guidance scale (default: 0.0)
  - output_format: Output format (default: "png")

  ## Returns
  - {:ok, output_path} on success
  - {:error, reason} on failure
  """
  def generate(prompt, opts \\ []) do
    GenServer.call(__MODULE__, {:generate, prompt, opts}, 60000)
  end

  @doc """
  Generate multiple images using the Zenoh service.

  ## Parameters
  - prompts: List of text prompts
  - opts: Options (same as generate/2)

  ## Returns
  - {:ok, results} - List of {:ok, path} | {:error, reason} tuples
  - {:error, reason} on connection failure
  """
  def generate_batch(prompts, opts \\ []) when is_list(prompts) do
    GenServer.call(__MODULE__, {:generate_batch, prompts, opts}, 120000)
  end

  @doc """
  Check if Zimage service is available.

  ## Returns
  - :ok if service is available
  - {:error, reason} if not available
  """
  def ping do
    GenServer.call(__MODULE__, :ping)
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    Logger.info("Starting ZimageClient...")

    case Zenohex.open() do
      {:ok, session} ->
        Logger.info("Zenoh session opened for client")
        {:ok, %{session: session}}

      {:error, reason} ->
        Logger.error("Failed to open Zenoh session: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:generate, prompt, opts}, _from, %{session: session} = state) do
    timeout = Keyword.get(opts, :timeout, 30000)

    params = %{
      "prompt" => prompt,
      "width" => Integer.to_string(Keyword.get(opts, :width, 1024)),
      "height" => Integer.to_string(Keyword.get(opts, :height, 1024)),
      "seed" => Integer.to_string(Keyword.get(opts, :seed, 0)),
      "num_steps" => Integer.to_string(Keyword.get(opts, :num_steps, 4)),
      "guidance_scale" => Float.to_string(Keyword.get(opts, :guidance_scale, 0.0)),
      "output_format" => Keyword.get(opts, :output_format, "png")
    }

    case Zenohex.Session.get(session, "zimage/generate", params) do
      {:ok, replies} ->
        # Wait for first reply with timeout
        receive_reply(replies, timeout)

      {:error, reason} ->
        {:reply, {:error, "Failed to send request: #{inspect(reason)}"}, state}
    end
  end

  @impl true
  def handle_call({:generate_batch, prompts, opts}, _from, %{session: session} = state) do
    timeout = Keyword.get(opts, :timeout, 30000)

    # Send requests concurrently
    tasks = Enum.map(prompts, fn prompt ->
      Task.async(fn ->
        params = %{
          "prompt" => prompt,
          "width" => Integer.to_string(Keyword.get(opts, :width, 1024)),
          "height" => Integer.to_string(Keyword.get(opts, :height, 1024)),
          "seed" => Integer.to_string(Keyword.get(opts, :seed, 0)),
          "num_steps" => Integer.to_string(Keyword.get(opts, :num_steps, 4)),
          "guidance_scale" => Float.to_string(Keyword.get(opts, :guidance_scale, 0.0)),
          "output_format" => Keyword.get(opts, :output_format, "png")
        }

        case Zenohex.Session.get(session, "zimage/generate", params) do
          {:ok, replies} ->
            case receive_reply(replies, timeout) do
              {:ok, path} -> {:ok, prompt, path}
              {:error, reason} -> {:error, prompt, reason}
            end

          {:error, reason} ->
            {:error, prompt, "Request failed: #{inspect(reason)}"}
        end
      end)
    end)

    # Collect results
    results = Task.yield_many(tasks, timeout + 1000)
    |> Enum.map(fn {task, result} ->
      case result do
        {:ok, reply} -> reply
        {:exit, reason} -> {:error, "unknown", "Task failed: #{inspect(reason)}"}
        nil -> {:error, "unknown", "Request timeout"}
      end
    end)

    {:reply, {:ok, results}, state}
  end

  @impl true
  def handle_call(:ping, _from, %{session: session} = state) do
    case Zenohex.Session.get(session, "zimage/service") do
      {:ok, _replies} ->
        {:reply, :ok, state}

      {:error, _reason} ->
        {:reply, {:error, "Service not available"}, state}
    end
  end

  @impl true
  def terminate(_reason, %{session: session}) do
    Zenohex.Session.close(session)
    Logger.info("ZimageClient terminated")
  end

  # Helper functions

  defp receive_reply(replies, timeout) do
    receive do
      {:zenoh_reply, reply} ->
        payload = Zenohex.Reply.payload(reply)

        case payload do
          %{"status" => "success", "output_path" => path} ->
            {:ok, path}

          %{"status" => "error", "reason" => reason} ->
            {:error, reason}

          _ ->
            {:error, "Invalid response format"}
        end

    after
      timeout ->
        {:error, "Request timeout"}
    end
  end
end