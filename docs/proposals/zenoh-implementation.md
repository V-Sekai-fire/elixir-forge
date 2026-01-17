# Amended Proposal: The Zenoh/Forge Fabric

The core shift here is moving from **"Addressing Sockets"** (ZeroMQ) to **"Addressing Data"** (Zenoh). In the Malamute pattern, the broker was the "Source of Truth" for where resources lived. In this Zenoh-based Forge, the **Network itself** is the Source of Truth.

#### 1. Why Zenoh over Malamute?

While Malamute was an elegant attempt to solve the "resource management" problem, it suffered from being a centralized bottle-neck.

| Feature | Malamute (The Old Goal) | Zenoh (The New Fabric) |
| --- | --- | --- |
| **Topology** | Centralized Broker | **True Peer-to-Peer / Routed Mesh** |
| **Data Locality** | Data must travel to the broker first. | **Geo-routing**; data flows the shortest path. |
| **Discovery** | Manual/ZBeacon logic. | **Inherent**; keys are discovered via gossip. |
| **Complexity** | You must build the "Mailbox" logic. | **Native Queryables**; requests find the data. |

---

### 2. Refined Message Flow: The "Unified" Fabric

In Zenoh, "Storage" and "Inference" use the same URI space. This means your Godot client doesn't need to know if a resource is a **cached result** or a **live AI model**.

```
    [URI: forge/inference/qwen] 
             |
    ---------------------------------
    |               |               |
[Queryable]    [Storage]       [Liveliness]
(Live Model)   (Cached Result) (Heartbeat)

```

#### Updated Inference Node Example (Python Zenoh)

Using the learnings from `chumak`, we ensure that the node remains lightweight and uses **Liveliness Tokens** instead of manual heartbeats. Instead of bridging via Elixir, we can directly use Python Zenoh clients for the AI scripts and connect to Godot via Zenoh Godot clients.

```python
# python/qwen_inference_node.py
import zenoh

# Open Zenoh session
session = zenoh.open(zenoh.Config())

# Declare Liveliness: This automatically tells the whole fabric "Qwen is Online"
# without sending a single packet.
liveliness = session.liveliness.declare_token("forge/services/qwen3vl")

# Declare Queryable: The "Management" endpoint.
queryable = session.declare_queryable("forge/inference/qwen")

# Process requests
for query in queryable.listener:
    # Lateral Thinking: If we are busy, Zenoh handles the backpressure.
    payload = query.payload
    
    # Process FlatBuffer (Zero-Copy)
    result = process_inference(payload)
    
    # Reply directly
    query.reply("forge/inference/qwen", result)
```

---

### 3. Solving the "Broken" WAN Problem

One of the biggest issues with the original Forge was that Wide Area Networks (WAN) would break the ZeroMQ connection. Zenoh solves this via **Scouting and Routing**:

* **Infrastructure Mode:** If your AI scripts are on a cloud GPU and your Godot client is at home, you can run a single `zenohd` router. The Python scripts and Godot client "scout" the router and form a bridge.
* **NAT Punching:** Zenoh’s QUIC transport is significantly better at traversing home routers than raw TCP/ZMTP.

### 4. Comparison Table: Final Verdict

| Metric | Forge (Chumak/Malamute) | Forge (Zenoh/Python) |
| --- | --- | --- |
| **Setup Time** | Weeks (Building the broker logic). | **Days** (Using native Queryables). |
| **Performance** | High (but limited by broker). | **Extreme** (P2P + shared memory). |
| **Scalability** | Manual load balancing. | **Automatic** (Anycast routing). |
| **State** | Lost if broker dies. | **Distributed** (Via Storage peers). |

### Implementation Status - COMPLETED ✅

This specification has been fully implemented in the Forge project:

- **zimage/**: Python AI service with Zenoh connectivity and Z-Image-Turbo generation
- **forge-client/**: Elixir CLI with service dashboard for live system monitoring
- **zenoh-router/**: Dedicated Elixir application for Zenoh daemon management

The system operates as a complete distributed AI platform with peer-to-peer networking, automatic service discovery, and binary transport protocols.

For usage, see the [main README](../README.md) and [CONTRIBUTING.md](../CONTRIBUTING.md) guides.
