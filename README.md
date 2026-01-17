# Forge

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Distributed AI platform with peer-to-peer networking via Zenoh.** Generates images using AI models and provides real-time service monitoring.

## Quick Start

```bash
# Single-command setup (2-5 minutes vs 15-30 manual)
./setup.sh

# Start services
./start.sh

# Generate images
./apps/forge-client/forge_client "sunset over mountains"
```

## Architecture

Elixir umbrella project with peer-to-peer networking:
- **apps/forge-client**: CLI tools and service dashboard
- **apps/ra-mailbox**: Distributed RA-based messaging
- **elixir/**: AI generation scripts
- **docs/**: Complete documentation and setup guides

## Documentation

📚 **[Full Documentation](docs/)** - Setup, architecture, API reference, and development guides

## License

MIT License - see [LICENSE](LICENSE)
