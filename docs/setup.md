# Setup and Deployment Guide

This guide covers setting up and deploying Livebook Nx in various environments.

## Prerequisites

### System Requirements

- **OS:** Linux, macOS, or Windows (WSL recommended for Windows)
- **Elixir:** 1.15+ with Erlang/OTP 26+
- **Python:** 3.8+ (managed via uv)
- **Memory:** 8GB+ RAM recommended, 16GB+ for GPU inference
- **Storage:** 20GB+ free space for models and data
- **GPU:** NVIDIA GPU with CUDA 11.8+ (optional but recommended)

### Dependencies

#### Required

- Elixir and Erlang
- Python 3.8+
- uv (Python package manager)

#### Optional (for full features)

- CockroachDB v22.1.64b21683521d9a8735ad
- SeaweedFS v4.05
- NVIDIA CUDA drivers

## Quick Setup

### Automated Setup

Run the provided setup script:

```bash
# Clone repository
git clone <repository-url>
cd livebook-nx

# Run automated setup
elixir setup.exs
```

This script will:

- Install Elixir dependencies
- Set up Python environment
- Create necessary directories
- Initialize configuration

### Manual Setup

1. **Install Elixir dependencies:**

   ```bash
   mix deps.get
   ```

2. **Compile the project:**

   ```bash
   mix compile
   ```

3. **Set up database (optional):**

   ```bash
   mix ecto.create
   mix ecto.migrate
   ```

4. **Verify installation:**
   ```bash
   mix test
   ```

## Environment Configuration

### Development Environment

Create `.env` file or set environment variables:

```bash
# Database (optional)
export DATABASE_URL="postgresql://user:pass@localhost:26257/livebook_nx"

# SeaweedFS (optional)
export SEAWEEDFS_MASTER="http://localhost:9333"
export SEAWEEDFS_FILER="http://localhost:8888"

# Python
export PYTHON_VERSION="3.11"
```

### Production Environment

Use `config/runtime.exs` for production configuration:

```elixir
import Config

# Production database config
config :livebook_nx, LivebookNx.Repo,
  username: System.get_env("DB_USERNAME"),
  password: System.get_env("DB_PASSWORD"),
  database: System.get_env("DB_NAME"),
  hostname: System.get_env("DB_HOST"),
  port: String.to_integer(System.get_env("DB_PORT") || "26257"),
  ssl: true,
  pool_size: String.to_integer(System.get_env("DB_POOL_SIZE") || "10")

# Production Oban config
config :livebook_nx, Oban,
  engine: Oban.Pro.Engines.Smart,
  queues: [
    default: String.to_integer(System.get_env("OBAN_DEFAULT_QUEUE") || "5"),
    ml: String.to_integer(System.get_env("OBAN_ML_QUEUE") || "8")
  ],
  repo: LivebookNx.Repo
```

## Distributed Storage Setup

### CockroachDB Setup

#### Using Docker (Development)

```bash
# Run CockroachDB
docker run -d \
  --name cockroach \
  -p 26257:26257 \
  -p 8080:8080 \
  -v cockroach-data:/cockroach/cockroach-data \
  cockroachdb/cockroach:v22.1.64b21683521d9a8735ad \
  start-single-node --insecure

# Create database
docker exec -it cockroach ./cockroach sql \
  --insecure \
  --execute="CREATE DATABASE livebook_nx;"
```

#### Production Cluster

```bash
# Initialize cluster
./cockroach init --certs-dir=certs --host=roach1:26257

# Create user and database
./cockroach sql --certs-dir=certs --host=roach1:26257 \
  --execute="
    CREATE USER livebook_nx WITH PASSWORD 'secure-password';
    CREATE DATABASE livebook_nx;
    GRANT ALL ON DATABASE livebook_nx TO livebook_nx;
  "
```

#### Configuration

```elixir
# config/runtime.exs
config :livebook_nx, LivebookNx.Repo,
  username: "livebook_nx",
  password: "secure-password",
  database: "livebook_nx",
  hostname: "roach1",
  port: 26257,
  ssl: true,
  ssl_opts: [
    cacertfile: "certs/ca.crt",
    certfile: "certs/client.livebook_nx.crt",
    keyfile: "certs/client.livebook_nx.key"
  ]
```

### SeaweedFS Setup

#### Single Node Setup

```bash
# Download SeaweedFS
wget https://github.com/seaweedfs/seaweedfs/releases/download/4.05/linux_amd64.tar.gz
tar -xzf linux_amd64.tar.gz

# Start master server
./weed master -port=9333

# Start volume server
./weed volume -dir=/tmp/seaweedfs -max=100 -mserver=localhost:9333 -port=8080

# Start filer
./weed filer -master=localhost:9333 -port=8888
```

#### Configuration

```elixir
# config/runtime.exs
config :livebook_nx,
  seaweedfs: %{
    master_url: System.get_env("SEAWEEDFS_MASTER") || "http://localhost:9333",
    filer_url: System.get_env("SEAWEEDFS_FILER") || "http://localhost:8888",
    replication: System.get_env("SEAWEEDFS_REPLICATION") || "001"
  }
```

## GPU Setup

### CUDA Installation

#### Ubuntu/Debian

```bash
# Install CUDA toolkit
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-ubuntu2004.pin
sudo mv cuda-ubuntu2004.pin /etc/apt/preferences.d/cuda-repository-pin-600
wget https://developer.download.nvidia.com/compute/cuda/11.8.0/local_installers/cuda_11.8.0_520.61.05_linux.run
sudo sh cuda_11.8.0_520.61.05_linux.run

# Install cuDNN
wget https://developer.download.nvidia.com/compute/cudnn/8.9.2/local_installers/cudnn-linux-x86_64-8.9.2.26_cuda11.8-archive.tar.xz
tar -xzf cudnn-linux-x86_64-8.9.2.26_cuda11.8-archive.tar.xz
sudo cp cudnn-linux-x86_64-8.9.2.26_cuda11.8-archive/include/cudnn*.h /usr/local/cuda/include
sudo cp cudnn-linux-x86_64-8.9.2.26_cuda11.8-archive/lib/libcudnn* /usr/local/cuda/lib64
```

#### Windows

```powershell
# Download CUDA installer from NVIDIA website
# Run installer with default options
# Restart system after installation
```

### PyTorch GPU Verification

```bash
# In Python environment
python -c "import torch; print(torch.cuda.is_available())"
```

## Deployment Options

### Local Development

```bash
# Run locally
mix phx.server  # If using Phoenix
# or
mix run --no-halt
```

### Docker Deployment

#### Dockerfile

```dockerfile
FROM elixir:1.15-alpine

# Install system dependencies
RUN apk add --no-cache \
    python3 \
    py3-pip \
    git \
    build-base

# Set working directory
WORKDIR /app

# Install Elixir dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod

# Copy application code
COPY . .

# Compile application
RUN mix compile

# Create release
RUN mix release

# Expose port (if using Phoenix)
EXPOSE 4000

# Start application
CMD ["_build/prod/rel/livebook_nx/bin/livebook_nx", "start"]
```

#### Docker Compose

```yaml
version: "3.8"

services:
  app:
    build: .
    ports:
      - "4000:4000"
    environment:
      - MIX_ENV=prod
      - DATABASE_URL=postgresql://user:pass@db:5432/livebook_nx
    depends_on:
      - db
      - seaweedfs

  db:
    image: cockroachdb/cockroach:v22.1.64b21683521d9a8735ad
    command: start-single-node --insecure
    ports:
      - "26257:26257"
      - "8080:8080"
    volumes:
      - cockroach-data:/cockroach/cockroach-data

  seaweedfs:
    image: chrislusf/seaweedfs:latest
    command: server -dir=/data -master.port=9333 -volume.port=8080 -filer.port=8888
    ports:
      - "9333:9333"
      - "8080:8080"
      - "8888:8888"
    volumes:
      - seaweedfs-data:/data

volumes:
  cockroach-data:
  seaweedfs-data:
```

### Kubernetes Deployment

#### Deployment Manifest

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: livebook-nx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: livebook-nx
  template:
    metadata:
      labels:
        app: livebook-nx
    spec:
      containers:
        - name: livebook-nx
          image: your-registry/livebook-nx:latest
          ports:
            - containerPort: 4000
          env:
            - name: MIX_ENV
              value: "prod"
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: db-secret
                  key: url
          resources:
            requests:
              memory: "2Gi"
              cpu: "1000m"
            limits:
              memory: "4Gi"
              cpu: "2000m"
          volumeMounts:
            - name: model-cache
              mountPath: /app/priv/pretrained_weights
      volumes:
        - name: model-cache
          persistentVolumeClaim:
            claimName: model-cache-pvc
```

#### Service Manifest

```yaml
apiVersion: v1
kind: Service
metadata:
  name: livebook-nx
spec:
  selector:
    app: livebook-nx
  ports:
    - port: 80
      targetPort: 4000
  type: LoadBalancer
```

### Cloud Deployment

#### AWS ECS/Fargate

```hcl
# Terraform example
resource "aws_ecs_task_definition" "livebook_nx" {
  family                   = "livebook-nx"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "2048"
  memory                   = "4096"

  container_definitions = jsonencode([
    {
      name  = "livebook-nx"
      image = "your-registry/livebook-nx:latest"
      portMappings = [
        {
          containerPort = 4000
          hostPort      = 4000
        }
      ]
      environment = [
        {
          name  = "MIX_ENV"
          value = "prod"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/livebook-nx"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}
```

## Monitoring and Observability

### OpenTelemetry Setup

```elixir
# config/runtime.exs
config :opentelemetry,
  service_name: "livebook_nx",
  service_version: "1.0.0",
  traces_exporter: :otlp

config :opentelemetry_exporter,
  otlp_protocol: :http_protobuf,
  otlp_endpoint: System.get_env("OTEL_ENDPOINT") || "http://localhost:4318"
```

### Health Checks

```elixir
# lib/livebook_nx/health.ex
defmodule LivebookNx.Health do
  def check do
    %{
      database: check_database(),
      python: check_python(),
      gpu: check_gpu()
    }
  end

  defp check_database do
    # Database connectivity check
  end

  defp check_python do
    # Python environment check
  end

  defp check_gpu do
    # GPU availability check
  end
end
```

### Logging

```elixir
# config/runtime.exs
config :logger,
  level: :info,
  backends: [:console, {LoggerFileBackend, :file_log}]

config :logger, :file_log,
  path: System.get_env("LOG_PATH") || "logs/livebook_nx.log",
  level: :debug
```

## Performance Tuning

### Database Optimization

```sql
-- CockroachDB optimizations
ALTER TABLE inferences CONFIGURE ZONE USING
  num_replicas = 3,
  constraints = '[+region=us-east1]';

-- Create indexes
CREATE INDEX ON inferences (status, inserted_at);
CREATE INDEX ON inferences (image_path);
```

### Application Tuning

```elixir
# config/runtime.exs
config :livebook_nx,
  inference_concurrency: System.get_env("INFERENCE_CONCURRENCY") || 5,
  model_cache_size: System.get_env("MODEL_CACHE_SIZE") || "10GB"
```

### Resource Limits

```bash
# System limits
echo "vm.max_map_count=262144" >> /etc/sysctl.conf
sysctl -p

# Python memory limits
export PYTHONMALLOC=jemalloc
```

## Backup and Recovery

### Database Backup

```bash
# CockroachDB backup
cockroach sql --certs-dir=certs \
  --execute="BACKUP inferences TO 's3://bucket/backups?AWS_ACCESS_KEY_ID=key&AWS_SECRET_ACCESS_KEY=secret';"
```

### Model Cache Backup

```bash
# Backup pretrained models
tar -czf models_backup.tar.gz priv/pretrained_weights/
aws s3 cp models_backup.tar.gz s3://bucket/models/
```

### Recovery Procedures

```bash
# Restore database
cockroach sql --certs-dir=certs \
  --execute="RESTORE inferences FROM 's3://bucket/backups';"

# Restore models
aws s3 cp s3://bucket/models/models_backup.tar.gz .
tar -xzf models_backup.tar.gz
```

## Security Considerations

### Network Security

- Use SSL/TLS for all connections
- Implement proper firewall rules
- Use VPC/security groups in cloud deployments

### Authentication

```elixir
# Basic auth example
config :livebook_nx,
  basic_auth: [
    username: System.get_env("ADMIN_USER"),
    password: System.get_env("ADMIN_PASS")
  ]
```

### Secrets Management

- Use environment variables for sensitive data
- Implement proper secret rotation
- Use cloud secret managers (AWS Secrets Manager, etc.)

## Troubleshooting

### Common Issues

1. **Model download failures:**

   ```bash
   # Clear cache and retry
   rm -rf priv/pretrained_weights/Huihui-Qwen3-VL-4B-Instruct-abliterated/
   mix qwen3vl test.jpg "test"
   ```

2. **Database connection issues:**

   ```bash
   # Test connection
   mix ecto.reset
   ```

3. **Memory issues:**

   ```bash
   # Monitor memory usage
   htop
   # Adjust configuration
   export ELIXIR_ERL_OPTIONS="+MMscs 8GB"
   ```

4. **GPU issues:**
   ```bash
   # Check GPU status
   nvidia-smi
   # Verify CUDA installation
   nvcc --version
   ```

### Debug Mode

```bash
# Enable debug logging
export LOG_LEVEL=debug
mix run --no-halt
```

### Performance Profiling

```elixir
# In IEx
:observer.start()
:fprof.apply(&LivebookNx.Qwen3VL.do_inference/1, [config], [])
:fprof.analyse()
```
