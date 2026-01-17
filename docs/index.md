# Livebook Nx Documentation

Welcome to the Livebook Nx documentation. This comprehensive guide covers everything you need to know about setting up, using, and extending the Livebook Nx AI inference platform.

## Quick Start

New to Livebook Nx? Start here:

1. **[Setup Guide](setup.md)** - Installation and deployment instructions
2. **[User Guide](user-guide.md)** - Core features and usage examples
3. **[API Reference](api.md)** - Complete technical documentation

## Documentation Overview

### User Documentation

- **[User Guide](user-guide.md)** - Complete guide for users
  - Overview and features
  - Quick start instructions
  - Configuration options
  - Troubleshooting

- **[Setup Guide](setup.md)** - Deployment and configuration
  - Prerequisites and system requirements
  - Local and production setup
  - Distributed storage (CockroachDB, SeaweedFS)
  - Docker and Kubernetes deployment
  - Performance tuning

- **[Third-Party Tools](third-party-tools.md)** - Integrated AI tools
  - Corrective Smooth Baker
  - KVoiceWalk (text-to-speech)
  - Mesh optimization tools
  - Character rigging utilities
  - Z-Image-Turbo (image generation)

### Developer Documentation

- **[API Reference](api.md)** - Technical reference
  - Core modules and functions
  - Database schema
  - CLI commands
  - Configuration files
  - Error handling

## Key Features

### AI Inference

- **Qwen3-VL Vision-Language Models** - State-of-the-art vision-language understanding
- **Asynchronous Processing** - Background job queues for long-running tasks
- **GPU Acceleration** - CUDA support for high-performance inference

### Distributed Storage

- **CockroachDB Integration** - Distributed SQL database for metadata and results
- **SeaweedFS Integration** - Distributed file storage for large assets

### Third-Party Tools

- **Mesh Processing** - Advanced 3D mesh optimization and smoothing
- **Text-to-Speech** - Neural voice synthesis with style control
- **Image Generation** - Turbo-accelerated image creation and editing
- **Character Rigging** - Automatic rigging and weight transfer

## Architecture

```
Livebook Nx
├── Core Application (Elixir/Phoenix)
│   ├── Qwen3-VL Inference Engine
│   ├── Job Queue (Oban)
│   └── Database Layer (Ecto)
├── Distributed Storage
│   ├── CockroachDB (Metadata)
│   └── SeaweedFS (Files)
└── Third-Party Tools
    ├── Mesh Processing
    ├── Audio Synthesis
    ├── Image Generation
    └── Character Rigging
```

## Getting Help

### Community Resources

- **GitHub Issues** - Report bugs and request features
- **Discussions** - Ask questions and share ideas
- **Wiki** - Community-contributed guides and tutorials

### Support Channels

- **Documentation Issues** - File issues for documentation problems
- **Feature Requests** - Suggest new features and improvements
- **Security Issues** - Report security vulnerabilities privately

## Contributing

We welcome contributions! See our [Contributing Guide](../CONTRIBUTING.md) for details on:

- Setting up a development environment
- Code style and standards
- Testing guidelines
- Submitting pull requests

### Documentation Contributions

- Fix typos or clarify explanations
- Add missing information
- Create tutorials and examples
- Translate documentation

## Version Information

- **Current Version**: 0.1.0
- **Last Updated**: January 9, 2026
- **Elixir Version**: 1.15+
- **Python Version**: 3.8+

## Changelog

See [CHANGELOG.md](../CHANGELOG.md) for version history and updates.

## License

This documentation is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.

---

**Need help?** Check the [troubleshooting section](user-guide.md#troubleshooting) in the user guide, or [file an issue](https://github.com/your-org/livebook-nx/issues) on GitHub.
