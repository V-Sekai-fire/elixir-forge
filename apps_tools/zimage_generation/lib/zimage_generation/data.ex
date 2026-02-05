defmodule ZImageGeneration.Data do
  @moduledoc """
  Data structure for flowing through Z-Image generation elements.
  """

  @type t :: %__MODULE__{
    prompt: String.t(),
    width: non_neg_integer(),
    height: non_neg_integer(),
    seed: non_neg_integer(),
    num_steps: pos_integer(),
    guidance_scale: float(),
    output_format: String.t(),
    output_path: Path.t() | nil
  }

  defstruct [
    :prompt,
    :width,
    :height,
    :seed,
    :num_steps,
    :guidance_scale,
    :output_format,
    :output_path
  ]

  @doc """
  Creates a new generation request.
  """
  def new(attrs \\ []) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Marks generation as complete with output path.
  """
  def complete(data, output_path) do
    %{data | output_path: output_path}
  end
end