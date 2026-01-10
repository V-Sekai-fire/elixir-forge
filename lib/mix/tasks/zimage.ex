defmodule Mix.Tasks.Zimage do
  @moduledoc """
  Generate images using Z-Image-Turbo.

  ## Usage

      mix zimage "<prompt>" [options]

  ## Options

      --width, -w         Image width in pixels (64-2048, default: 1024)
      --height, -h        Image height in pixels (64-2048, default: 1024)
      --seed, -s          Random seed (0 for random, default: 0)
      --steps             Number of inference steps (default: 4)
      --guidance-scale, -g Guidance scale (default: 0.0)
      --format, -f        Output format: png, jpg, jpeg (default: png)
      --help              Show this help message

  ## Examples

      mix zimage "a beautiful sunset over mountains"
      mix zimage "a cat wearing a hat" --width 512 --height 512 --seed 42
      mix zimage "futuristic cityscape" --steps 8 --format jpg
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    # Start the application to ensure the GenServer is running
    Mix.Task.run("app.start")

    case parse_args(args) do
      {:help} ->
        print_help()

      {:error, message} ->
        Mix.shell().error("Error: #{message}")
        print_help()
        exit({:shutdown, 1})

      {:ok, config} ->
        generate_images(config)
    end
  end

  defp parse_args(args) do
    {opts, prompts, _} = OptionParser.parse(args,
      switches: [
        width: :integer,
        height: :integer,
        seed: :integer,
        steps: :integer,
        guidance_scale: :float,
        format: :string,
        help: :boolean
      ],
      aliases: [
        w: :width,
        h: :height,
        s: :seed,
        g: :guidance_scale,
        f: :format
      ]
    )

    if Keyword.get(opts, :help, false) do
      {:help}
    else
      case validate_args(prompts, opts) do
        :ok ->
          config = %{
            prompts: prompts,
            width: Keyword.get(opts, :width, 1024),
            height: Keyword.get(opts, :height, 1024),
            seed: Keyword.get(opts, :seed, 0),
            num_steps: Keyword.get(opts, :steps, 4),
            guidance_scale: Keyword.get(opts, :guidance_scale, 0.0),
            output_format: Keyword.get(opts, :format, "png")
          }
          {:ok, config}

        {:error, message} ->
          {:error, message}
      end
    end
  end

  defp validate_args(prompts, opts) do
    cond do
      prompts == [] ->
        {:error, "At least one text prompt is required"}

      Keyword.get(opts, :width, 1024) < 64 or Keyword.get(opts, :width, 1024) > 2048 ->
        {:error, "Width must be between 64 and 2048 pixels"}

      Keyword.get(opts, :height, 1024) < 64 or Keyword.get(opts, :height, 1024) > 2048 ->
        {:error, "Height must be between 64 and 2048 pixels"}

      Keyword.get(opts, :steps, 4) < 1 ->
        {:error, "Number of steps must be at least 1"}

      Keyword.get(opts, :guidance_scale, 0.0) < 0.0 ->
        {:error, "Guidance scale must be non-negative"}

      Keyword.get(opts, :format, "png") not in ["png", "jpg", "jpeg"] ->
        {:error, "Output format must be png, jpg, or jpeg"}

      true ->
        :ok
    end
  end

  defp generate_images(config) do
    prompts = config.prompts
    prompt_count = length(prompts)

    Mix.shell().info("Starting Z-Image-Turbo generation for #{prompt_count} prompt(s)...")

    results = Enum.with_index(prompts, 1)
    |> Enum.map(fn {prompt, index} ->
      Mix.shell().info("[#{index}/#{prompt_count}] Generating: #{prompt}")

      options = [
        width: config.width,
        height: config.height,
        seed: config.seed,
        num_steps: config.num_steps,
        guidance_scale: config.guidance_scale,
        output_format: config.output_format
      ]

      case LivebookNx.Server.run_zimage_generation(prompt, options) do
        {:ok, output_path} ->
          Mix.shell().info("  ✓ Success: #{output_path}")
          {:ok, output_path}

        {:error, reason} ->
          Mix.shell().error("  ✗ Failed: #{inspect(reason)}")
          {:error, reason}
      end
    end)

    # Summary
    success_count = Enum.count(results, fn
      {:ok, _} -> true
      _ -> false
    end)

    failed_count = prompt_count - success_count

    Mix.shell().info("")

    if failed_count == 0 do
      Mix.shell().info("=== ALL SUCCESSFUL (#{success_count}/#{prompt_count}) ===")
      Mix.shell().info("All #{success_count} image(s) generated successfully!")

      results
      |> Enum.filter(fn {:ok, path} -> path end)
      |> Enum.each(fn {:ok, path} -> Mix.shell().info("  • #{path}") end)
    else
      Mix.shell().info("=== PARTIAL SUCCESS (#{success_count}/#{prompt_count} succeeded) ===")

      if success_count > 0 do
        Mix.shell().info("Successful generations:")
        results
        |> Enum.with_index(1)
        |> Enum.filter(fn
          {{:ok, _}, _} -> true
          _ -> false
        end)
        |> Enum.each(fn {{:ok, path}, idx} -> Mix.shell().info("  [#{idx}] #{path}") end)
        Mix.shell().info("")
      end

      if failed_count > 0 do
        Mix.shell().error("Failed generations:")
        results
        |> Enum.with_index(1)
        |> Enum.filter(fn
          {{:error, _}, _} -> true
          _ -> false
        end)
        |> Enum.each(fn {{:error, reason}, idx} -> Mix.shell().error("  [#{idx}] #{inspect(reason)}") end)
      end

      exit({:shutdown, 1})
    end
  end

  defp print_help do
    Mix.shell().info(@moduledoc)
  end
end
