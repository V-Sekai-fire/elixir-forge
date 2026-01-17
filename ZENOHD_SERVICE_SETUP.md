# Zenoh Router Daemon - User Service Setup

This guide sets up `zenohd` as a systemd **user service** with optional **HTTP Bridge** for seamless operation within your user session. This provides better reliability than background processes and integrates with system logging.

## Architecture Options

Zenoh supports two access patterns:

### Option 1: HTTP Bridge (Recommended)
```
Web/Curl Clients → zenohd (REST Plugin) → Zenoh network → Backend Services
       🌐             📡                     🔧                🔬
```

- **Access:** `curl http://localhost:7447/apis/service/endpoint`
- **Compatible with:** All HTTP clients (browsers, curl, python requests, etc.)
- **Requirements:** zenohd with REST plugin (system install or pre-built)

### Option 2: Zenoh Native (Advanced)
```
Zenoh Clients → zenohd (Basic) → Zenoh network → Backend Services
       🔷            📡              🔧               🔬
```

- **Access:** `./zimage_client` (Zenoh-based CLI)
- **Compatible with:** Zenoh client libraries (Rust, Python, Elixir, etc.)
- **Requirements:** Basic zenohd (cargo install works)

## Prerequisites

- **zenohd installed** (see main README.md for installation options)
- **systemd user services enabled** (usually default on modern Linux)

## Setup Instructions

### 1. Install the Service File

Copy the service template to your user systemd directory:

```bash
# Create the directory if it doesn't exist
mkdir -p ~/.config/systemd/user

# Copy the service file from the project
cp zenohd.service ~/.config/systemd/user/
```

**OR** edit manually to adjust paths:

Depending on your zenohd installation:

**For Cargo zenohd (no HTTP bridge):**
The template defaults work as-is.

**For zenohd with HTTP bridge (REST plugin):**
Enable HTTP access by uncommenting the REST line in the service:

```bash
systemctl --user edit zenohd
```

Then modify the ExecStart to include REST:

```ini
[Service]
# Uncomment this line for HTTP bridge:
ExecStart=%h/.cargo/bin/zenohd --listen tcp/[::]:7447 --rest-http-port 7447
```

If you installed differently, adjust the paths:

```ini
# System-wide install with REST:
ExecStart=zenohd --listen tcp/[::]:7447 --rest-http-port 7447

# Custom path:
ExecStart=/custom/path/to/zenohd --listen tcp/[::]:7447 --rest-http-port 7447
```

Apply changes and restart:

```bash
systemctl --user daemon-reload
systemctl --user restart zenohd
```

### 2. Reload systemd User Daemon

```bash
systemctl --user daemon-reload
```

### 3. Enable the Service (Auto-start)

```bash
systemctl --user enable zenohd
```

This enables zenohd to start automatically when you log in.

### 4. Start the Service

```bash
systemctl --user start zenohd
```

### 5. Verify Operation

```bash
# Check status
systemctl --user status zenohd

# View logs
journalctl --user -u zenohd --follow

# Test REST API
curl http://localhost:7447/@config/admin/version
```

You should see zenohd running and the REST API responding.

## Management Commands

### Basic Control
```bash
# Start service
systemctl --user start zenohd

# Stop service
systemctl --user stop zenohd

# Restart
systemctl --user restart zenohd

# Check status
systemctl --user status zenohd
```

### Monitoring
```bash
# View logs (real-time)
journalctl --user -u zenohd --follow

# View last 50 log entries
journalctl --user -u zenohd -n 50

# View logs since yesterday
journalctl --user -u zenohd --since yesterday
```

### Administration
```bash
# Disable auto-start on login
systemctl --user disable zenohd

# Re-enable auto-start
systemctl --user enable zenohd

# Reload configuration (after editing service file)
systemctl --user daemon-reload
```

## Integration with Forge

### Boot Script
The `./boot_forge.sh` script now integrates with the user service:

- **Checks** if zenohd service is available via `systemctl --user`
- **Starts** service with `systemctl --user start zenohd`
- **Stops gracefully** with `systemctl --user stop zenohd`

This ensures proper systemd integration vs manual background processes.

### Manual boot_shutdown
If you prefer manual control:
```bash
# Start zenohd service
systemctl --user start zenohd

# Start Forge services
cd zimage && uv run python inference_service.py &
cd ../forge-client && ./zimage_client --dashboard &

# Stop all later
systemctl --user stop zenohd
```

## Troubleshooting

### Service Won't Start

**Check zenohd path:**
```bash
# Verify zenohd executable location
which zenohd
ls ~/.cargo/bin/zenohd
```

**Update service file ExecStart path if needed:**
```bash
systemctl --user edit zenohd
# Edit: ExecStart=/correct/path/to/zenohd --listen tcp/[::]:7447 --rest-api
systemctl --user daemon-reload
```

### Port Conflicts

**Change default port (7447) if conflict:**
```bash
systemctl --user edit zenohd
# Edit: ExecStart=... --listen tcp/[::]:8080 --rest-api
systemctl --user daemon-reload
systemctl --user restart zenohd

# Update boot_forge.sh if changing port
```

**Check what's using port 7447:**
```bash
sudo netstat -tulpn | grep :7447
lsof -i :7447
```

### Permission Issues

**Systemd user services don't have root access.** If you need privileged ports (<1024), either:
1. Use unprivileged ports (7447 is fine)
2. Install zenohd as system service (not covered here)

### Service Starts but Forge Can't Connect

**Check service is actually running:**
```bash
systemctl --user status zenohd
# Should show "Active: active (running)"
```

**Verify port listening:**
```bash
ss -tulpn | grep zenohd
# Should show tcp    LISTEN  127.0.0.1:7447
```

**Test direct connection:**
```bash
curl http://localhost:7447/@config/admin/version
# Should return JSON
```

## Advanced Configuration

### Custom Configuration File

Instead of command arguments, use a zenohd config file:

Create `~/.config/zenohd.json5`:

```json5
{
  listen: {
    endpoints: ["tcp/[::]:7447"]
  },
  plugins: {
    rest: {},
    admin: {}
  }
}
```

Then update service file:
```ini
ExecStart=%h/.cargo/bin/zenohd --config %h/.config/zenohd.json5
```

### Environment Variables

Add to service file under `[Service]` section:
```ini
Environment=ZENOH_LOG_LEVEL=info
Environment=RUST_LOG=zenoh=debug
Environment=ZENOH_ADMIN_SPACE=^zenohd/**
```

### Persistence

By default, service stops on logout. To persist across sessions (global login):

Edit `~/.config/systemd/user/zenohd.service`:

```ini
[Service]
RemainAfterExit=yes
```

**Note:** This is experimental and may not work across all display managers.

## Reference

- **Zenoh Documentation:** https://zenoh.io/docs/
- **Systemd User Services:** `man systemd-user`
- **Service Commands:** `man systemctl`

For Forge platform usage, see the main README.md.
