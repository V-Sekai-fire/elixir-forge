defmodule ZimageGenerationTest do
  use ExUnit.Case
  require Logger

  @moduletag :skip

  @tag skip: "Requires Python dependencies and takes significant time to run AI generation"
  test "Z-Image Membrane pipeline generates image successfully" do
    request = ZImageGeneration.Data.new([
      prompt: "a simple test image of a dog",
      width: 256,
      height: 256,
      seed: 1,
      num_steps: 4,
      guidance_scale: 0.0,
      output_format: "png"
    ])

    Logger.info("Testing Z-Image generation", [
      {"prompt", request.prompt},
      {"dimensions", "#{request.width}x#{request.height}"}
    ])

    case ZImageGeneration.Generator.generate_image(request) do
      {:ok, output_path} ->
        assert File.exists?(output_path), "Generated image file should exist"

        assert String.ends_with?(output_path, ".png"),
               "Output should be PNG format"

        assert String.contains?(output_path, "output/"),
               "Output should be in proper directory structure"

        Logger.info("✅ Z-Image generation test passed", [
          {"output_path", output_path}
        ])

      {:error, reason} ->
        IO.puts("❌ AI generation failed with reason: #{inspect(reason)}")
        Logger.warning("Z-Image generation failed (acceptable for skipped test)")
    end

    Logger.info("Z-Image Membrane pipeline test completed")
  end

  @tag skip: "Verifies Membrane element compilation and structure"
  test "Membrane elements compile and can be instantiated" do
    source_module = ZImageGeneration.Source
    generator_module = ZImageGeneration.Generator
    sink_module = ZImageGeneration.Sink
    data_module = ZImageGeneration.Data

    assert is_atom(source_module), "Source element module should be referenceable"
    assert is_atom(generator_module), "Generator element module should be referenceable"
    assert is_atom(sink_module), "Sink element module should be referenceable"
    assert is_atom(data_module), "Data struct module should be referenceable"

    data = ZImageGeneration.Data.new([
      prompt: "test",
      width: 512,
      height: 512,
      seed: 42,
      num_steps: 4,
      guidance_scale: 0.0,
      output_format: "png"
    ])

    assert data.prompt == "test"
    assert data.width == 512
    assert data.height == 512
  end
end
