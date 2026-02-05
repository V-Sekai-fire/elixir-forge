defmodule ZImageGeneration.Sink do
  @moduledoc """
  Membrane sink element for Z-Image generation output.

  Receives completed ZImageGeneration.Data with output paths,
  performs final processing and notifications.
  """

  use Membrane.Sink
  require OpenTelemetry.Tracer

  def_input_pad :input, accepted_format: ZImageGeneration.Data

  @impl true
  def handle_init(_ctx, _opts) do
    {[], %{completed_generations: []}}
  end

  @impl true
  def handle_buffer(:input, %Membrane.Buffer{payload: %ZImageGeneration.Data{output_path: output_path} = data}, _ctx, state) do
    OpenTelemetry.Tracer.with_span "zimage.sink.process_completion" do
      OpenTelemetry.Tracer.set_attribute("sink.output_path", output_path)
      OpenTelemetry.Tracer.set_attribute("sink.prompt_length", String.length(data.prompt))

      # Log successful completion
      IO.puts("✓ Image generated: #{output_path}")
      IO.puts("  Prompt: #{data.prompt}")
      IO.puts("  Dimensions: #{data.width}x#{data.height}")
      IO.puts("  Steps: #{data.num_steps}, Seed: #{data.seed}")
      IO.puts("  Format: #{String.upcase(data.output_format)}")
      IO.puts("")

      # Notify parent of completion
      actions = [notify_parent: {:generation_complete, output_path, data}]
      state = %{state | completed_generations: [output_path | state.completed_generations]}

      {actions, state}
    end
  end

  @impl true
  def handle_end_of_stream(:input, _ctx, state) do
    # Final summary
    complete_count = length(state.completed_generations)
    IO.puts("=== Z-IMAGE GENERATION COMPLETE ===")
    IO.puts("Generated #{complete_count} image(s)")
    IO.puts("")

    if complete_count > 0 do
      IO.puts("Generated files:")
      state.completed_generations
      |> Enum.reverse()
      |> Enum.each(fn path ->
        IO.puts("  • #{path}")
      end)
    end

    # Reset for potential reuse
    {[], %{state | completed_generations: []}}
  end

  @impl true
  def handle_event(_pad, _event, _ctx, state) do
    {[], state}
  end
end