defmodule Mix.Tasks.Qwen3vl do
  @moduledoc "Run Qwen3-VL inference"
  @shortdoc "qwen3vl <image_path> <prompt> [options]"

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    # Start the application to ensure the GenServer is running
    Mix.Task.run("app.start")

    {opts, args, _} = OptionParser.parse(args,
      switches: [
        max_tokens: :integer,
        temperature: :float,
        top_p: :float,
        output: :string,
        use_flash_attention: :boolean,
        use_4bit: :boolean,
        full_precision: :boolean
      ],
      aliases: [
        m: :max_tokens,
        t: :temperature,
        o: :output
      ]
    )

    case args do
      [image_path, prompt] ->
        options = [
          max_tokens: opts[:max_tokens],
          temperature: opts[:temperature],
          top_p: opts[:top_p],
          output_path: opts[:output],
          use_flash_attention: opts[:use_flash_attention],
          use_4bit: if(opts[:full_precision], do: false, else: opts[:use_4bit] || true)
        ]

        case Forge.Server.run_qwen3vl_inference(image_path, [prompt: prompt] ++ options) do
          {:ok, result} ->
            Mix.shell().info("Qwen3-VL inference completed:")
            Mix.shell().info(result)

          {:error, reason} ->
            Mix.shell().error("Qwen3-VL inference failed: #{inspect(reason)}")
            exit({:shutdown, 1})
        end

      _ ->
        Mix.shell().error("Usage: mix qwen3vl <image_path> <prompt> [options]")
        exit({:shutdown, 1})
    end
  end
end
