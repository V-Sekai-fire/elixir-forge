# Contributing to Forge

## Overview

Forge is a distributed AI platform using Zenoh for peer-to-peer communication and Deep Learning inference, powered by Z-Image-Turbo model integration. This guide covers development setup, coding standards, and contribution guidelines.

## Development Setup

### Prerequisites

- Python 3.11+
- Elixir 1.14+
- uv (Python package manager) or pip
- mix (Elixir build tool)
- Rust + Cargo (for Zenoh development)
- FlatBuffers compiler (flatc)

### Environment Setup

#### Python (zimage service)

```bash
cd zimage
uv sync  # Install dependencies
```

#### Elixir (zimage-client)

```bash
cd zimage-client
mix deps.get  # Install Elixir dependencies
mix escript.build  # Build CLI executable
```

#### Zenoh Router (for E2E testing)

```bash
# Install zenoh router
cargo install eclipse-zenohd  # Requires Rust
# Or use pre-built binaries from zenoh.io

# Run router for development
zenohd
```

## Development Workflow

### 1. Choose Your Component

- **zimage/**: Python service for AI inference (Hugging Face diffusers, FlatBuffers)
- **zimage-client/**: Elixir CLI and dashboard for service interaction
- **Zenoh Integration**: Cross-language P2P communication protocols

### 2. Make Changes

- Feature development on topic branches
- Keep commits focused and well-described
- Test locally before pushing

### 3. Testing

```bash
# Build and test all components
cd zimage && uv run python inference_service.py  # Demo run
cd ../zimage-client && mix test && mix escript.build
go test  # If adding Go components
./test_e2e.sh  # Integration test
```

### 4. Submit PR

- Include comprehensive description
- Reference related issues
- Add/update tests

## Architecture Guidelines

### Zenoh Integration

- Use URI-based service discovery (`forge/services/**`, `zimage/generate/**`)
- Implement liveliness tokens for service announcement
- Follow request-response patterns with FlatBuffers/FlexBuffers serialization

### Python Development

- **Dependencies**: Committed pyproject.toml with uv lockfiles
- **Imports**: Standard library first, then third-party, then local
- **Async/Await**: Use for all I/O operations in zenoh communication
- **Error Handling**: Try/except with descriptive messages
- **Logging**: Use Python logging module

### Elixir Development

- **Naming**: snake_case for functions/files, PascalCase for modules
- **OTP**: Leverage GenServer, Supervisor patterns
- **Documentation**: Use @doc/@moduledoc
- **Testing**: ExUnit with descriptive test names
- **Dependencies**: Managed via mix.exs

## Code Quality Standards

### Linting & Formatting

```bash
# Python
uv run flake8 zimage/  # Style checking
uv run black zimage/  # Code formatting

# Elixir
mix format  # Standard formatting
mix credo   # Code analysis
```

### Testing

- **Unit Tests**: Cover all module functions
- **Integration Tests**: E2E flows via zenoh network
- **Performance Tests**: Measure latency for AI inference
- **Network Tests**: Zenoh discovery and message routing

### Documentation

- **Code**: Use docstrings/doc comments
- **Architecture**: Update docs/ for major changes
- **APIs**: Document FlatBuffers schemas and URI patterns

## Zenoh-Specific Guidelines

### Message Serialization

```python
# Use FlatBuffers for request/response structure
# Use FlexBuffers for variable metadata
# Follow glTF2 extension patterns for future evolution
```

### Service Discovery

```python
# Liveliness tokens for service announcement
# Queryable endpoints for request handling
# Subscriber patterns for monitoring
```

### Error Handling

- Zenoh network failures should be recoverable
- Failed AI inference should return structured error responses
- Graceful degradation when services unavailable

## Performance Considerations

### AI Inference

- Local model caching in `pretrained_weights/`
- GPU optimization (torch.compile, memory format)
- Batch processing for multiple requests
- Memory management with PyTorch garbage collection

### Network Communication

- Minimal serialization overhead with FlatBuffers
- Connection pooling in Zenoh sessions
- Backpressure handling for high-throughput scenarios

## Git Workflow

### Branch Naming

- `feature/zenoh-optimization`
- `fix/client-serialization`
- `docs/api-update`

### Commit Messages

```
type(scope): description

Types: feat, fix, docs, style, refactor, test, chore
Scope: component name (zimage, client, zenoh)
```

### Pull Request Template

- **Description**: What changes and why
- **Testing**: How verified (unit, integration, e2e)
- **Performance Impact**: Any latency/throughput changes
- **Breaking Changes**: API/protocol modifications

## Getting Help

### Resources

- **Zenoh Documentation**: https://zenoh.io/
- **FlatBuffers Guide**: https://google.github.io/flatbuffers/
- **Hugging Face Diffusers**: https://huggingface.co/docs/diffusers
- **Elixir Guides**: https://elixir-lang.org/getting-started

### Community

- Issues on GitHub for bug reports/feature requests
- Discussion forum for design/architecture questions
- Code reviews required for all PRs

## License & Contributions

By contributing, you agree that your contributions will be licensed under the same MIT license as the project. Contributions are welcome and appreciated!
