defmodule ZImageGeneration.Source do
  @moduledoc """
  Membrane source element for Z-Image generation.

  Accepts generation requests with prompts and parameters,
  then outputs ZImageGeneration.Data structs for processing.
  """

  use Membrane.Source
  require OpenTelemetry.Tracer

  @impl true
  def handle_init(_ctx, opts) do
    requests = Keyword.get(opts, :requests, [])
    {[], %{requests: requests, current_index: 0}}
  end

  @impl true
  def handle_playing(_ctx, state) do
    if state.current_index < length(state.requests) do
      process_next_request([], state)
    else
      {[end_of_stream: :output], state}
    end
  end

  @impl true
  def handle_event(_pad, _event, _ctx, state) do
    {[], state}
  end

  # Remove these callbacks as they're not implemented in Membrane.Element behaviour
  # @impl true
  # def handle_keyframe(_payload, _pts, _dts, state) do
  #   {[], state}
  # end

  # @impl true
  # def handle_write(_event, _pts, _limit, state) do
  #   {[], state}
  # end

  # Private functions

  defp process_next_request(_actions, state) do
    {request, remaining_requests} = List.pop_at(state.requests, state.current_index)

    OpenTelemetry.Tracer.with_span "zimage.source.new_request" do
      OpenTelemetry.Tracer.set_attribute("request.index", state.current_index)
      OpenTelemetry.Tracer.set_attribute("request.prompt", String.length(request.prompt))

      actions_output = [{:buffer, {:output, request}}]
      state = %{state | requests: remaining_requests, current_index: state.current_index + 1}

      if state.current_index < length(state.requests) do
        # Schedule next processing
        {actions_output ++ [notify_parent: {:request_processed, state.current_index}], state}
      else
        {actions_output, state}
      end
    end
  end
end