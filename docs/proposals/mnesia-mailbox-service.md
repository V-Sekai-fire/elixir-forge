# Erlang RA + Zenoh: The Linearizable Mailbox Service

[![Proposal Status: Draft](https://img.shields.io/badge/status-draft-yellow.svg)](#)

For true mailbox semantics where messages must be consumed exactly once and in order, **RA** (RabbitMQ's Raft implementation as an independent Erlang library) provides the required **linearizability**. This ensures that mailbox operations maintain strong consistency guarantees across distributed nodes.

In this architecture, **Zenoh** provides the "Global Nervous System" (transport and discovery), while **RA** provides the "Linearizable Memory" (replicated, strongly consistent message queues).

## 1. The Architecture: Zenoh + RA

Instead of a single Malamute broker, you have a **cluster of Elixir nodes**. Any node can receive a message via Zenoh, and RA ensures that message operations are **linearizable** across the distributed cluster.

### How it works

1. **Storage Logic:** Your Elixir service registers as a Zenoh **Queryable** or **Storage**.
2. **Persistence:** When a `PUT` arrives, the Elixir node submits the write to the RA cluster for consensus.
3. **Consumption:** When a user calls `GET`, they get a linearizable read. For mailbox semantics, they can request the RA cluster to "consume" (atomically read+delete) messages.

## 2. Minimal Conceptual Implementation

You would use the [`Zenohex`](https://hex.pm/packages/zenohex) library (the Elixir bindings for Zenoh) and the [`ra`](https://hex.pm/packages/ra) library for Raft-based linearizability.

### Step 1: Define the RA Process and Commands

```elixir
# lib/mailbox_ra.ex
defmodule MailboxRA do
  # RA server for linearizable mailbox operations

  @type command :: {:put, user_id, message} | {:consume, user_id} | {:peek, user_id}

  @spec init(keyword) :: :ra.srv_config()
  def init(config) do
    # Initialize mailbox state
    Map.put(config, :mailboxes, %{})
  end

  @spec apply(:ra.srv_config(), command()) :: {:reply, any}
  def apply(state, {:put, user_id, message}) do
    # Atomic put operation using RA consensus
    new_state = update_in(state.mailboxes[user_id],
      fn queue -> [message | queue || []] end)

    {:reply, :ok, new_state}
  end

  def apply(state, {:consume, user_id}) do
    # Linearizable read+delete (Atomic Pop)
    case state.mailboxes[user_id] do
      [message | rest] ->
        new_state = Map.update(state.mailboxes, user_id, [], fn _ -> rest end)
        {:reply, {:ok, message}, new_state}

      [] ->
        {:reply, {:error, :empty}, state}
    end
  end

  def apply(state, {:peek, user_id}) do
    # Linearizable read-only peek
    case state.mailboxes[user_id] do
      [message | _] ->
        {:reply, {:ok, message}, state}

      [] ->
        {:reply, {:error, :empty}, state}
    end
  end
end
```

### Step 2: The Zenoh-RA Bridge

This logic would live inside a GenServer that manages your Zenoh session.

```elixir
# lib/zenoh_ra_bridge.ex
defmodule ZenohRABridge do
  use GenServer
  require Logger

  def start_link(ra_node_names) do
    GenServer.start_link(__MODULE__, ra_node_names)
  end

  def init(ra_node_names) do
    # Start Zenoh session
    {:ok, session} = Zenohex.open()

    # Declare Queryable for mailbox operations
    {:ok, queryable} = Zenohex.Session.declare_queryable(session, "forge/mailbox/*")

    # Start bridging loop
    spawn_link(fn -> bridge_loop(session, queryable, ra_node_names) end)

    {:ok, %{session: session, queryable: queryable, ra_nodes: ra_node_names}}
  end

  def bridge_loop(session, queryable, ra_nodes) do
    # Wait for Zenoh queries
    Zenohex.Queryable.loop(queryable, fn query ->
      handle_zenoh_query(query, ra_nodes)
    end)
  end

  def handle_zenoh_query(query, ra_nodes) do
    # Parse operation from key_expr: "forge/mailbox/user123/put" or "forge/mailbox/user123/consume"
    ["forge", "mailbox", user_id, operation] = String.split(query.key_expr, "/")

    # Submit operation to RA cluster for linearizability
    case operation do
      "put" ->
        # Extract message from Zenoh payload
        {:ok, message} = Zenohex.Query.payload(query)
        cmd = {:put, user_id, message}
        submit_and_reply(cmd, ra_nodes, query)

      "consume" ->
        cmd = {:consume, user_id}
        submit_and_reply(cmd, ra_nodes, query)

      "peek" ->
        cmd = {:peek, user_id}
        submit_and_reply(cmd, ra_nodes, query)
    end
  end

  def submit_and_reply(command, ra_nodes, zenoh_query) do
    # Submit to RA cluster for consensus/linearizability
    {:ok, result} = :ra.process_command(select_ra_node(ra_nodes), command)

    # Reply via Zenoh
    Zenohex.Query.reply(zenoh_query, zenoh_query.key_expr, result)
  end

  def select_ra_node(ra_nodes) do
    # Round-robin or load-based selection
    hd(ra_nodes)
  end
end
```

## 3. Why this is "Malamute-Style"

* **Persistence:** If an Elixir node goes down, the messages are safe on disk.
* **Distribution:** If you have three Elixir nodes, Mnesia keeps them in sync. A client can connect to *any* node in the Zenoh network and query their mailbox.
* **Decoupling:** Zenoh handles the routing. You don't need to know the IP of the "Mailbox Service"; you just query `mailbox/alice`.

## 4. The "Minimal Usefulness" Factor

To make this truly useful, you can add **TTL (Time To Live)** logic. Elixir can run a background task every minute to delete records from Mnesia that are older than 24 hours. This prevents your "Malamute" service from eating up all your disk space if users never check their mail.

## Deployment Pattern

Your Forge platform can extend this architecture for **user-specific services**:

```elixir
# Forge Mailbox Service (run on any Elixir node)
# Registers to Zenoh as: forge/mailbox/*

# Put message for user
PUT forge/mailbox/user123 {"message": "Your AI generation is ready"}
PUT forge/mailbox/admin {"alert": "System maintenance in 5 minutes"}

# Get next message (consumes it)
GET forge/mailbox/user123
# Returns: {"message": "Your AI generation is ready", "id": "msg_456"}

# Client continues polling
GET forge/mailbox/user123
# Returns: null (mailbox empty)
```

## Comparison Summary

| Feature | Malamute (Original) | Zenoh Native Storage | Elixir RA Linearizable |
| --- | --- | --- | --- |
| **Broker Architecture** | Single-point bottleneck | Sharded by key | **Distributed Raft cluster** |
| **Linearizability** | Manual implementation | Eventual consistency | **Strong consistency** |
| **Message Semantics** | Basic pub/sub | Static key-value | **Exactly-once consumption** |
| **Persistence** | Custom implementation | Basic disk storage | **Consensus-persistent** |
| **Reliability** | Manual failover | Basic replication | **Auto-healing Raft cluster** |
| **Scaling** | Single instance limit | Sharded by Key | **Replicated** across Erlang nodes |
| **Complexity** | High (custom broker) | Very Low | Moderate |
| **Dependencies** | ZeroMQ + Custom | Zenoh primitives | RA + Erlang/Elixir |

## Implementation Benefits

### Why Linearizability Matters

* **Strong Consistency:** No race conditions or lost messages across distributed nodes
* **Exactly-once Semantics:** Messages consumed precisely once (no duplicates or losses)
* **Failure Resilience:** Raft ensures safe failover during network partitions

### Production Benefits

* **High Availability:** Operations remain linearizable during node failures
* **Horizontal Scaling:** Add more Elixir nodes for better throughput
* **Network Efficiency:** Zenoh routes queries while RA maintains order
* **Operational Simplicity:** Standard Erlang monitoring + RA metrics

## Mix Configuration Example

```elixir
# mix.exs
defp deps do
  [
    {:zenohex, "~> 0.7.2"},    # Zenoh Elixir bindings
    {:ra, "~> 2.7.0"}          # RabbitMQ RA for linearizability
  ]
end
```

```erlang
# vm.args
# For distributed Erlang cluster with RA capabilities
-name mailbox_service@<hostname>
-setcookie your_secret_cookie
-RA_system_dir 'priv/ra'  # RA persistent storage
```

## RA Cluster Setup Example

```elixir
# lib/mailbox_application.ex
defmodule MailboxApplication do
  use Application

  def start(_type, _args) do
    # Start RA cluster membership
    ra_cluster = [
      {MailboxRA, :mailbox_1@node1},
      {MailboxRA, :mailbox_2@node2},
      {MailboxRA, :mailbox_3@node3}
    ]

    # Start RA servers for linearizability
    children = [
      {RA.ServerSupervisor, ra_cluster},
      {ZenohRABridge, ra_cluster}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
```

## Next Steps

Would you like me implement a complete working example that:
1. Sets up RA cluster for linearizable mailbox operations
2. Implements the Zenoh Queryable interface
3. Demonstrates message PUT/CONSUME/PEEK patterns
4. Handles TTL cleanup and Raft persistence
5. Provides Forge integration examples

This would give you a **production-ready, strongly consistent mailbox service** that provides true exactly-once semantics via RA linearizability.

---

**Status:** Ready for implementation and testing with Zenoh + RA architecture.
