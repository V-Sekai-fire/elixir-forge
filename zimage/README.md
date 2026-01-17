# Zimage

A standalone Elixir application for Z-Image-Turbo image generation with Zenoh integration.

## Installation

```bash
cd zimage
mix deps.get
mix compile
```

## Usage

### Direct API

```elixir
# Generate a single image
{:ok, path} = Zimage.generate("a beautiful sunset")

# Generate with custom options
{:ok, path} = Zimage.generate("a cat wearing a hat", width: 512, height: 512, seed: 42)

# Generate multiple images
{:ok, paths} = Zimage.generate_batch(["cat", "dog", "bird"])
```

### Zenoh Service

The application runs as a Zenoh service that accepts generation requests:

```bash
# Start the service
mix run

# The service will be available at 'zimage/generate'
```

#### Requesting Generation via Zenoh

From another Elixir node or application:

```elixir
# Open Zenoh session
{:ok, session} = Zenohex.open()

# Query for image generation
{:ok, reply} = Zenohex.Session.get(session, "zimage/generate", %{
  "prompt" => "a beautiful landscape",
  "width" => "1024",
  "height" => "1024"
})

# Process the reply
case reply do
  %{"status" => "success", "output_path" => path} ->
    IO.puts("Image generated: #{path}")
  %{"status" => "error", "reason" => reason} ->
    IO.puts("Generation failed: #{reason}")
end
```

## Running

```bash
# Start the Zenoh-enabled application
mix run

# Or run interactively
iex -S mix
```

## Dependencies

- Pythonx for Python interop
- Zenohex for Zenoh protocol
- Diffusers, Transformers, etc. via UV