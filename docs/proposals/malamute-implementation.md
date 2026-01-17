# Proposal: Implementing Malamute Protocol in Forge for Distributed AI Processing

## Overview

Forge is a multi-modal AI content creation platform that integrates various AI models and processing tools. Currently, the system uses standalone Elixir scripts in the `elixir/` directory for tasks like image generation, vision-language processing, TTS synthesis, and 3D processing. To enable efficient coordination and communication between these components, we propose implementing the Malamute protocol using Chumak as the messaging backbone.

## Background

### Current Architecture
- **Standalone Scripts**: Each AI task runs as an independent `.exs` script
- **No Inter-Process Communication**: Scripts operate in isolation
- **Manual Coordination**: Users must manually chain operations
- **Limited Scalability**: No distributed processing capabilities

### Malamute Protocol
Malamute is a messaging protocol built on ZeroMQ that provides:
- **Mailboxes**: Named message queues for processes
- **Streams**: Persistent event logs for data flow
- **Service Discovery**: Automatic client-broker connections
- **Load Balancing**: Distributed workload management

While Malamute doesn't exist as a pre-packaged Elixir library, it can be implemented using Chumak (the Erlang ZeroMQ driver) to speak the MLM (Malamute) protocol.

## Proposed Implementation

### 1. Core Components

#### Malamute Broker (Fabric)
- **Elixir GenServer** using Chumak for ZMTP transport
- **Mailbox Management**: Process registration and message routing
- **Stream Handling**: Event log persistence for workflow tracking
- **Service Discovery**: Automatic client connection management

#### Malamute Clients
- **Modified Scripts**: Each `elixir/*.exs` becomes a Malamute client
- **Protocol Adapters**: MLM binary parsers for message encoding/decoding
- **Mailbox Registration**: Scripts register with specific service names

### 2. Message Flow Architecture

```
User Request → Malamute Broker → Processing Pipeline
    ↓              ↓              ↓
Qwen3-VL     Z-Image-Turbo    Kokoro TTS
Analysis     Generation       Synthesis
    ↓              ↓              ↓
Results → Stream Updates → Client Notifications
```

### 3. Protocol Implementation

#### MLM Binary Parser
Using Elixir's powerful binary pattern matching:

```elixir
defmodule MLM.Parser do
  # Parse MLM frames
  def parse_frame(<<0x01, _::binary>> = frame) do
    # MAILBOX-DELIVER
    {:mailbox_deliver, parse_mailbox_deliver(frame)}
  end
  
  def parse_frame(<<0x02, _::binary>> = frame) do
    # STREAM-DELIVER  
    {:stream_deliver, parse_stream_deliver(frame)}
  end
  
  # ... additional frame types
end
```

#### Broker Implementation
```elixir
defmodule Forge.Malamute.Broker do
  use GenServer
  
  def init(_) do
    {:ok, socket} = Chumak.socket(:router)
    Chumak.bind(socket, "tcp://*:9999")
    {:ok, %{socket: socket, mailboxes: %{}, streams: %{}}}
  end
  
  def handle_info({:zmq, socket, message}, state) do
    case MLM.Parser.parse_frame(message) do
      {:mailbox_send, %{address: addr, content: content}} ->
        route_to_mailbox(state, addr, content)
      # ... handle other message types
    end
    {:noreply, state}
  end
end
```

### 4. Script Integration

#### Current Script Structure
- `qwen3vl_inference.exs`: Vision-language analysis
- `zimage_generation.exs`: Image generation  
- `kokoro_tts_generation.exs`: Text-to-speech
- `sam3_video_segmentation.exs`: Video processing

#### Modified Script Structure
Each script becomes a Malamute client:

```elixir
defmodule Forge.Scripts.Qwen3VL do
  def run(image_path, prompt) do
    # Connect to Malamute broker
    {:ok, client} = Malamute.Client.start_link()
    
    # Register mailbox
    Malamute.Client.mailbox_open(client, "qwen3vl-service")
    
    # Process request
    result = Qwen3VL.infer(image_path, prompt)
    
    # Send result to stream
    Malamute.Client.stream_send(client, "results", result)
    
    result
  end
end
```

### 5. Benefits

#### Improved Coordination
- **Pipeline Orchestration**: Automatic chaining of AI tasks
- **Error Handling**: Centralized failure management
- **Load Balancing**: Distribute work across multiple instances

#### Scalability
- **Horizontal Scaling**: Add more processing nodes
- **Resource Management**: Monitor and allocate compute resources
- **Fault Tolerance**: Automatic failover and recovery

#### Developer Experience
- **Standardized Interface**: Consistent API for all scripts
- **Debugging**: Centralized logging and monitoring
- **Testing**: Isolated component testing with message mocking

## Implementation Plan

### Phase 1: Core Protocol (Week 1-2)
- Implement MLM binary parser
- Create basic broker GenServer
- Unit tests for protocol compliance

### Phase 2: Client Library (Week 3)
- Malamute client module
- Mailbox and stream APIs
- Integration tests

### Phase 3: Script Migration (Week 4-5)
- Convert one script to Malamute client
- Test end-to-end message flow
- Migrate remaining scripts

### Phase 4: Production Features (Week 6)
- Persistence for streams
- Monitoring and metrics
- Docker containerization

## Dependencies

- **Chumak**: ZeroMQ driver for Erlang/Elixir
- **Erlang/OTP 25+**: For GenServer and process management
- **Elixir 1.14+**: For scripting and pattern matching

## Risk Assessment

### Low Risk
- Chumak is mature and well-tested
- MLM protocol is simple and well-documented
- Incremental migration approach

### Mitigation Strategies
- Start with simple mailbox-only implementation
- Comprehensive test coverage
- Rollback to standalone scripts if needed

## Success Metrics

- **Latency**: <100ms message routing
- **Throughput**: 1000+ messages/second
- **Reliability**: 99.9% message delivery
- **Compatibility**: All existing scripts functional

## Conclusion

Implementing Malamute in Forge will transform our collection of standalone scripts into a cohesive, distributed AI processing platform. By leveraging Chumak and Elixir's strengths, we can achieve reliable inter-process communication without external dependencies.

The phased approach ensures minimal disruption while providing a foundation for future scalability and feature development.

**Ready to proceed with Phase 1 implementation?**