# Forge Architectural Proposals

This directory contains architectural proposals for the Forge distributed AI platform, covering both the original Nx/Elixir + CockroachDB investigation and the current Zenoh-based distributed networking architecture.

## Network Architecture Proposals

- **[Zenoh Implementation](zenoh-implementation.md)** - Complete deployment guide for switching from Malamute/ZeroMQ to Zenoh distributed networking
- **[RA Mailbox Service](mnesia-mailbox-service.md)** - Advanced message broker pattern using Erlang RA + Zenoh for linearizable, distributed mailboxes
- **[Tools Research](tools_research.md)** - Investigation of performance between ZeroMQ and Zenoh for Forge's networking needs

## Original Database Latency Proposals

This proposal outlines porting the smallest AI model to Nx/Elixir for testing 60ms database latency using CockroachDB v22.1.64b21683521d9a8735ad and SeaweedFS 4.05 for distributed storage.

This proposal has been split into the following sections:

- [Expected Latency Impact](latency-impact.md)
- [Model Selection](model-selection.md)
- [Optimization Strategies](optimization-strategies.md)
- [Overview](overview.md)
- [Porting Process](porting-process.md)
- [Summary](summary.md)
- [Trial Goals](trial-goals.md)

## Research Archive

- **[Third Party Tools](..//third-party-tools.md)** - Reference documentation for integrated tooling
- **[User Guide](../user-guide.md)** - Platform user experience and operations
