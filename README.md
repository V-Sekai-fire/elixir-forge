# Forge

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Elixir](https://img.shields.io/badge/Elixir-1.15+-purple)](https://elixir-lang.org/)

A comprehensive computation platform featuring multi-modal computing models including Z-Image-Turbo image generation and Qwen3-VL vision-language models.

## ✨ Features

- **Image Generation**: Z-Image-Turbo for high-speed text-to-image creation
- **Vision-Language Processing**: Qwen3-VL model for image understanding and description
- **Synchronous Processing**: Direct execution without job queues or databases
- **Multi-Modal Pipeline**: End-to-end automated workflows combining generation and analysis
- **Production Ready**: Containerized deployment with optimized performance

## 🚀 Quick Start

```bash
# Install dependencies
mix deps.get
mix compile

# Run inference immediately
mix qwen3vl image.jpg "What do you see?"
mix zimage "a beautiful sunset"
```

```bash
# Install dependencies
mix deps.get
mix compile

### Run Inference

```bash
# Describe an image
mix qwen3vl image.jpg "What do you see?"

# Generate an image
mix zimage "a beautiful sunset over mountains"
```

### Additional Command Options

```bash
# With custom options
mix qwen3vl photo.png "Analyze in detail" --max-tokens 200 --temperature 0.8
mix zimage "fantasy landscape" --width 1024 --height 512 --seed 42
```

## �📚 Documentation

- **[📖 User Guide](docs/user-guide.md)** - Complete usage guide
- **[🛠️ Setup Guide](docs/setup.md)** - Installation and deployment
- **[🔧 API Reference](docs/api.md)** - Technical documentation
- **[🧰 Third-Party Tools](docs/third-party-tools.md)** - Integrated processing tools

## 🏗️ Architecture

```
Forge
├── Core Application (Elixir)
│   ├── Z-Image Inference Engine
│   ├── Qwen3-VL Vision-Language Engine
│   └── Synchronous Processing
├── Processing Models
│   ├── Z-Image-Turbo (Image Generation)
│   └── Qwen3-VL (Vision Analysis)
└── Third-Party Tools
    ├── Mesh Processing
    ├── Audio Synthesis
    ├── Image Generation
    └── Character Rigging
```

**Note**: Third-party tools are optional integrations.

## 🐳 Deployment

### Docker

```bash
docker build -t forge .
docker run -p 4000:4000 forge
```

### Docker Compose

```bash
docker-compose up -d
```

See [Setup Guide](docs/setup.md) for detailed deployment instructions.

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙋 Support

- 📖 [Documentation](docs/)
- 🐛 [Issues](https://github.com/your-org/forge/issues)
- 💬 [Discussions](https://github.com/your-org/forge/discussions)
