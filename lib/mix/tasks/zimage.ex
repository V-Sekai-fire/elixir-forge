defmodule Mix.Tasks.Zimage do
  @moduledoc "Generate an image with Z-Image-Turbo"
  @shortdoc "zimage <prompt> [options]"

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    # Start the application to ensure the GenServer is running
    Mix.Task.run("app.start")

    {opts, args, _} = OptionParser.parse(args,
      switches: [
        width: :integer,
        height: :integer,
        seed: :integer,
        num_steps: :integer,
        guidance_scale: :float,
        format: :string,
        output: :string
      ],
      aliases: [
        w: :width,
        h: :height,
        s: :seed,
        n: :num_steps,
        g: :guidance_scale,
        f: :format,
        o: :output
      ]
    )

    case args do
      [prompt] ->
        options = [
          width: opts[:width],
          height: opts[:height],
          seed: opts[:seed],
          num_steps: opts[:num_steps],
          guidance_scale: opts[:guidance_scale],
          output_format: opts[:format],
          output_path: opts[:output]
        ]

        case Forge.ZImage.generate(prompt, options) do
          {:ok, image_path} ->
            Mix.shell().info("Image generated successfully: #{image_path}")

          {:error, reason} ->
            Mix.shell().error("Image generation failed: #{inspect(reason)}")
            exit({:shutdown, 1})
        end

      _ ->
        Mix.shell().error("Usage: mix zimage <prompt> [options]")
        Mix.shell().info("""
        Options:
          -w, --width WIDTH      Image width (default: 1024)
          -h, --height HEIGHT    Image height (default: 1024)
          -s, --seed SEED        Random seed (default: random)
          -n, --num-steps N      Inference steps (default: 4)
          -g, --guidance-scale G Guidance scale (default: 0.0)
          -f, --format FORMAT    Output format: png, jpg, jpeg (default: png)
          -o, --output PATH      Custom output path
        """)
        exit({:shutdown, 1})
    end
  end
end
