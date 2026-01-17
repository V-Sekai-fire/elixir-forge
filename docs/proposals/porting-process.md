## Porting Process

1. **Adapt the existing Livebook script** (`qwen3vl_inference.exs`) to work within our Elixir application.
2. **Integrate with Oban** for job queuing and background processing.
3. **Set up SeaweedFS 4.05** for distributed file storage of model weights and outputs.
4. **Configure CockroachDB v22.1.64b21683521d9a8735ad** cluster for low-latency database operations.
5. **Test latency impact** using the 60ms remote database connection.
