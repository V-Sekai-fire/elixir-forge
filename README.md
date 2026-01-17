# Forge

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Elixir](https://img.shields.io/badge/Elixir-1.15+-purple)](https://elixir-lang.org/)

A comprehensive computation platform featuring multi-modal computing models including Z-Image-Turbo image generation and Qwen3-VL vision-language models.

## ✨ Features

- **Image Generation**: Z-Image-Turbo for high-speed text-to-image creation
- **Vision-Language Processing**: Qwen3-VL model for image understanding and description
- **Synchronous Processing**: Direct execution without job queues or databases
- **Multi-Modal Pipeline**: End-to-end automated workflows combining generation and analysis
- **Script-Based Execution**: Standalone Elixir scripts for flexible processing

## 🚀 Quick Start

```bash
# Run inference directly
elixir elixir/qwen3vl_inference.exs image.jpg "What do you see?"
elixir elixir/zimage_generation.exs "a beautiful sunset"
```

## �📚 Documentation

- **[📖 User Guide](docs/user-guide.md)** - Complete usage guide
- **[🛠️ Setup Guide](docs/setup.md)** - Installation and deployment
- **[🔧 API Reference](docs/api.md)** - Technical documentation
- **[🧰 Third-Party Tools](docs/third-party-tools.md)** - Integrated processing tools

## 🏗️ Architecture

```
Forge
├── Elixir Scripts
│   ├── qwen3vl_inference.exs (Vision-Language Processing)
│   ├── zimage_generation.exs (Image Generation)
│   ├── kokoro_tts_generation.exs (Text-to-Speech)
│   ├── sam3_video_segmentation.exs (Video Processing)
│   └── Other AI Processing Scripts
├── Third-Party Tools
│   ├── Mesh Processing
│   ├── Audio Synthesis
│   ├── Image Generation
│   └── Character Rigging
└── Documentation
    ├── Proposals
    ├── Setup Guides
    └── API References
```

**Note**: Third-party tools are optional integrations. Scripts run independently.

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙋 Support

- 📖 [Documentation](docs/)
- 🐛 [Issues](https://github.com/V-Sekai-fire/forge/issues)
- 💬 [Discussions](https://github.com/V-Sekai-fire/forge/discussions)
