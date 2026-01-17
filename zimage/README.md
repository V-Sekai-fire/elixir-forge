# Zimage

A standalone Elixir application for Z-Image-Turbo image generation.

## Installation

```bash
cd zimage
mix deps.get
mix compile
```

## Usage

```elixir
# Generate a single image
{:ok, path} = Zimage.generate("a beautiful sunset")

# Generate with custom options
{:ok, path} = Zimage.generate("a cat wearing a hat", width: 512, height: 512, seed: 42)

# Generate multiple images
{:ok, paths} = Zimage.generate_batch(["cat", "dog", "bird"])
```

## Running

```bash
# Start the application
mix run

# Or run interactively
iex -S mix
```

## Dependencies

- Pythonx for Python interop
- Diffusers, Transformers, etc. via UV