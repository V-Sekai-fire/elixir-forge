# Forge

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Elixir](https://img.shields.io/badge/Elixir-1.15+-purple)](https://elixir-lang.org/)

A comprehensive computation platform featuring multi-modal computing models including Z-Image-Turbo image generation and Qwen3-VL vision-language models, with SQLite-backed job processing.

## ✨ Features

- **Image Generation**: Z-Image-Turbo for high-speed text-to-image creation
- **Vision-Language Processing**: Qwen3-VL model for image understanding and description
- **SQLite Database**: Embedded database with job queue persistence
- **Async Processing**: Oban job system for background task execution
- **Multi-Modal Pipeline**: End-to-end automated workflows combining generation and analysis
- **Production Ready**: Containerized deployment with optimized performance

## 🚀 Quick Start

### Basic Setup (No Database Required)

```bash
# Install dependencies
mix deps.get
mix compile

# Run inference immediately
mix qwen3vl image.jpg "What do you see?"
```

### Full Setup (With Database & Job Queues)

```bash
# Install dependencies
mix deps.get
mix compile

# Create SQLite database and run migrations
mix ecto.setup                   # Auto-creates SQLite DB and tables
```

### Run Inference

```bash
# Describe an image
mix qwen3vl image.jpg "What do you see?"

# Generate an image
mix zimage "a beautiful sunset over mountains"

# Queue for background processing (requires database)
{:ok, job} = Forge.Qwen3VL.queue_inference("image.jpg", "Describe this image")
```

### Additional Command Options

```bash
# With custom options
mix qwen3vl photo.png "Analyze in detail" --max-tokens 200 --temperature 0.8
mix zimage "fantasy landscape" --width 1024 --height 512 --seed 42
```

## 🗄️ Database Configuration

Forge uses SQLite as an embedded database for job queue persistence and background task management. The database is automatically created and managed by the application.

### Database Features

- **Embedded SQLite**: File-based database, no external dependencies
- **Job Persistence**: Oban queues store background processing jobs
- **Migration Support**: Automatic schema creation and updates
- **Concurrent Access**: SQLite WAL mode for better performance

### Database Setup

```bash
# Create database and run all migrations
mix ecto.setup

# Run migrations only
mix ecto.migrate

# View job queue status
mix oban.tel
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
│   ├── Job Queue System (Oban)
│   └── SQLite Database (Ecto)
├── Processing Models
│   ├── Z-Image-Turbo (Image Generation)
│   └── Qwen3-VL (Vision Analysis)
└── Third-Party Tools
    ├── Mesh Processing
    ├── Audio Synthesis
    ├── Image Generation
    └── Character Rigging
```

**Note**: Database is embedded SQLite. Third-party tools are optional integrations.

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
