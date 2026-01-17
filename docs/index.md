# Forge Documentation

Welcome to the Forge documentation. This comprehensive guide covers the Zenoh-powered distributed AI platform for peer-to-peer image generation and service monitoring.

## Quick Start

New to Forge? Start here:

1. **[Setup Guide](../CONTRIBUTING.md#development-setup)** - Installation and development setup
2. **[User Guide](../README.md)** - Core features and usage examples
3. **[Zenoh Implementation](proposals/zenoh-implementation.md)** - Technical architecture overview

## Documentation Overview

### User Documentation

- **[Main README](../README.md)** - Platform overview with quick start
  - Component descriptions
  - Installation instructions
  - Usage examples
  - Architecture diagram

- **[Contributing Guide](../CONTRIBUTING.md)** - Development setup and guidelines
  - Development environment setup
  - Zenoh integration guidelines
  - Code quality standards
  - Git workflow

- **[Third-Party Tools](third-party-tools.md)** - Scripting ecosystem
  - Corrective Smooth Baker
  - KVoiceWalk (text-to-speech)
  - Mesh optimization tools
  - Character rigging utilities

### Developer Documentation

- **[Zenoh Implementation](proposals/zenoh-implementation.md)** - Technical design
  - Peer-to-peer networking concepts
  - FlatBuffer schemas and protocols
  - Service discovery mechanisms

- **[API Reference](api.md)** - Technical reference
  - Component interfaces
  - Zenoh URI patterns
  - CLI command specifications

## Key Features

### Distributed AI Generation

- **Z-Image-Turbo Integration** - GPU-optimized text-to-image generation
- **Peer-to-Peer Networking** - Zenoh for service discovery and routing
- **Real-Time Monitoring** - Live service dashboards and health checks
- **Binary Transport** - FlatBuffers for efficient data exchange

### Platform Components

- **zimage/**: Python AI service with Hugging Face diffusers
- **forge-client/**: Elixir CLI tools and service monitoring
- **zenoh-router/**: Dedicated Zenoh router daemon management

### Networking Features

- **Automatic Discovery**: Services find each other via Zenoh
- **Location Transparency**: Work across local networks or WAN
- **Scalability**: Horizontal service scaling without reconfiguration

## Architecture

```
[forge-client] ←→ [zenoh-router] ←→ [zimage service]
  Live Dashboard      P2P Network        AI Generation
   (Elixir CLI)         (Zenoh)            (Python)
       ↓                    |
      [boot_forge.sh] ←→ Configured System
          ↑
    Automated Startup
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
