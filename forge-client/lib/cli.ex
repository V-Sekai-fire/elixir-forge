defmodule ZimageClient.CLI do
  @moduledoc """
  Command-line interface for ZimageClient.
  """

  def main(args) do
    {opts, args, _} = OptionParser.parse(args,
      switches: [
        width: :integer,
        height: :integer,
        seed: :integer,
        num_steps: :integer,
        guidance_scale: :float,
        output_format: :string,
        batch: :boolean,
        dashboard: :boolean,
        router: :boolean,
        help: :boolean
      ],
      aliases: [
        w: :width,
        h: :height,
        s: :seed,
        b: :batch,
        d: :dashboard,
        r: :router,
        help: :boolean
      ]
    )

    if Keyword.get(opts, :help, false) do
      show_help()
      System.halt(0)
    end

    if Keyword.get(opts, :dashboard, false) do
      ZimageClient.Dashboard.start()
      System.halt(0)
    end

    if Keyword.get(opts, :router, false) do
      start_router()
      System.halt(0)
    end

    # Check if service is available
    case ZimageClient.Client.ping() do
      :ok ->
        IO.puts("✓ Zimage service is available")

      {:error, reason} ->
        IO.puts("✗ Zimage service not available: #{reason}")
        System.halt(1)
    end

    if Keyword.get(opts, :batch, false) do
      # Batch mode - all args are prompts
      prompts = args
      if prompts == [] do
        IO.puts("Error: At least one prompt required for batch mode")
        System.halt(1)
      end

      IO.puts("Requesting batch generation of #{length(prompts)} images...")

      case ZimageClient.Client.generate_batch(prompts, opts) do
        {:ok, results} ->
          success_count = Enum.count(results, fn {status, _, _} -> status == :ok end)
          IO.puts("\n=== Results: #{success_count}/#{length(prompts)} successful ===")

          Enum.each(results, fn
            {:ok, prompt, path} ->
              IO.puts("✓ '#{prompt}' -> #{path}")
            {:error, prompt, reason} ->
              IO.puts("✗ '#{prompt}' -> #{reason}")
          end)

        {:error, reason} ->
          IO.puts("Batch request failed: #{reason}")
          System.halt(1)
      end

    else
      # Single mode
      prompt = Enum.join(args, " ")
      if prompt == "" do
        IO.puts("Error: Prompt required")
        System.halt(1)
      end

      IO.puts("Requesting image generation for: #{prompt}")

      case ZimageClient.Client.generate(prompt, opts) do
        {:ok, path} ->
          IO.puts("✓ Image generated: #{path}")

        {:error, reason} ->
          IO.puts("✗ Generation failed: #{reason}")
          System.halt(1)
      end
    end
  end

  defp start_router do
    IO.puts("Starting Zenoh router (zenohd)...")

    # Check if zenohd is available
    with {0, _} <- System.cmd("which", ["zenohd"]),
         IO.puts("✓ Found zenohd binary") do

      IO.puts("Starting zenohd on localhost:7447...")

      # Start zenohd as a subprocess
      # Note: This will run in the foreground, blocking this Elixir process
      # User can Ctrl+C to stop it
      case System.cmd("zenohd", [], into: IO.stream(:stdio, :write)) do
        {output, 0} ->
          IO.puts("Zenoh router stopped gracefully")
        {error_output, code} ->
          IO.puts("Zenoh router exited with code #{code}: #{error_output}")
          System.halt(1)
      end
    else
      {_code, _} ->
        IO.puts("""
        ✗ zenohd not found in PATH.

        Install zenohd to provide the Zenoh router:
        1. Install Rust: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
        2. Install Zenoh: cargo install zenohd
        3. Or see: https://zenoh.io/download/

        Zenoh router is required for P2P communication between clients and services.
        """)
        System.halt(1)
    end
  end

  defp show_help do
    IO.puts("""
    ZimageClient - Request image generation and monitor services via Zenoh

    USAGE:
      zimage_client "prompt" [options]
      zimage_client --batch "prompt1" "prompt2" [options]
      zimage_client --dashboard
      zimage_client --router

    OPTIONS:
      -w, --width WIDTH          Image width (default: 1024)
      -h, --height HEIGHT        Image height (default: 1024)
      -s, --seed SEED            Random seed (default: 0)
      --num-steps STEPS          Number of inference steps (default: 4)
      --guidance-scale SCALE     Guidance scale (default: 0.0)
      --output-format FORMAT     Output format: png, jpg, jpeg (default: png)
      -b, --batch                Batch mode - multiple prompts
      -d, --dashboard            Launch service dashboard to monitor active AI services
      -r, --router               Start Zenoh router daemon (zenohd) for P2P networking
      --help                     Show this help

    EXAMPLES:
      zimage_client "a beautiful sunset"
      zimage_client "a cat wearing a hat" --width 512 --height 512
      zimage_client --batch "cat" "dog" "bird" --width 256
      zimage_client --dashboard
      zimage_client --router
    """)
  end
end
