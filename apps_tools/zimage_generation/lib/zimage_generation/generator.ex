defmodule ZImageGeneration.Generator do
  @moduledoc """
  Membrane generator element for Z-Image AI generation.

  Receives ZImageGeneration.Data from source, performs AI image generation,
  and outputs completed data with output paths.
  """

  use Membrane.Filter
  alias ZImageGeneration.Data
  require OpenTelemetry.Tracer

  def_input_pad :input, accepted_format: ZImageGeneration.Data
  def_output_pad :output, accepted_format: ZImageGeneration.Data

  @impl true
  def handle_init(_ctx, _opts) do
    {[], %{setup_complete: false}}
  end

  @impl true
  def handle_playing(_ctx, state) do
    actions = [demand: {:input, 1}]
    {actions, state}
  end

  @impl true
  def handle_buffer(:input, %Membrane.Buffer{payload: %ZImageGeneration.Data{} = data}, _ctx, state) do
    case generate_image(data) do
      {:ok, output_path} ->
        completed_data = Data.complete(data, output_path)
        actions = [buffer: {:output, completed_data}, demand: {:input, 1}]

        OpenTelemetry.Tracer.with_span "zimage.generator.success" do
          OpenTelemetry.Tracer.set_attribute("generator.output_path", output_path)
          OpenTelemetry.Tracer.set_status(:ok)
        end

        {actions, state}

      {:error, reason} ->
        OpenTelemetry.Tracer.with_span "zimage.generator.error" do
          OpenTelemetry.Tracer.set_attribute("generator.error", inspect(reason))
          OpenTelemetry.Tracer.set_status(:error, inspect(reason))
        end

        {[demand: {:input, 1}, notify_parent: {:generation_failed, reason}], state}
    end
  end

  @impl true
  def handle_event(_pad, _event, _ctx, state) do
    {[], state}
  end

  @impl true
  def handle_end_of_stream(:input, _ctx, state) do
    {[end_of_stream: :output], state}
  end

  # Private functions

  def generate_image(data) do
    OpenTelemetry.Tracer.with_span "zimage.generator.generate_image" do
      OpenTelemetry.Tracer.set_attribute("image.width", data.width)
      OpenTelemetry.Tracer.set_attribute("image.height", data.height)
      OpenTelemetry.Tracer.set_attribute("image.seed", data.seed)
      OpenTelemetry.Tracer.set_attribute("image.num_steps", data.num_steps)
      OpenTelemetry.Tracer.set_attribute("image.guidance_scale", data.guidance_scale)
      OpenTelemetry.Tracer.set_attribute("prompt.length", String.length(data.prompt))

      try do
        # Create output directory
        output_dir = Path.expand("output")
        File.mkdir_p!(output_dir)

        # Create timestamped folder
        tag = time_tag()
        export_dir = Path.join(output_dir, tag)
        File.mkdir_p!(export_dir)

        # Render EEx templates for Python code
        load_code = render_template("load_code", %{})
        generate_code = render_template("generate_code", %{})

        # Pass config data via globals to avoid JSON parsing issues
        config_data = Jason.encode!(%{
          prompt: data.prompt,
          width: data.width,
          height: data.height,
          seed: data.seed,
          num_steps: data.num_steps,
          guidance_scale: data.guidance_scale,
          output_format: data.output_format,
          tag: tag
        })

        # Execute Python generation (load first, then generate)
        {_, globals_after_load} = Pythonx.eval(load_code, %{})

        # Generate with the pipeline and config data in globals
        {result, _globals_after_generate} = Pythonx.eval(generate_code, Map.put(globals_after_load, "config_json", config_data))

        # Result should be the output path string from Python
        case result do
          %Pythonx.Object{} = py_obj ->
            case Pythonx.decode(py_obj) do
              path when is_binary(path) -> {:ok, path}
              other -> {:error, "Expected string path, got: #{inspect(other)}"}
            end
          path when is_binary(path) -> {:ok, path}
          other -> {:error, "Failed to generate image, result was: #{inspect(other)}"}
        end

      rescue
        e ->
          {:error, Exception.message(e)}
      end
    end
  end

  # Render EEx template from priv/templates directory
  defp render_template(template_name, assigns) do
    template_path = Application.app_dir(:zimage_generation, "priv/templates/#{template_name}.eex")
    EEx.eval_file(template_path, assigns: assigns)
  end

  defp time_tag do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.to_string()
    |> String.replace(["-", ":", "."], "_")
    |> String.slice(0, 19)
  end
end