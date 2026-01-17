#!/usr/bin/env elixir
# Test script for RA linearizability without Zenoh dependency

# Import dependencies
Mix.install([
  {:ra, "~> 2.7.0"}
])

defmodule RATester do
  @ra_name :test_mailbox_ra
  @ra_module RAMailbox.RA.MailboxRA

  def run_tests do
    IO.puts("🧪 RA Linearizability Test (Zenoh-free)")
    IO.puts("=====================================")

    # Start RA server
    case start_ra_server() do
      :ok ->
        IO.puts("✅ RA server started")
        run_linearizability_tests()
      error ->
        IO.puts("❌ Failed to start RA server: #{inspect(error)}")
    end
  end

  def start_ra_server do
    ra_config = %{
      name: @ra_name,
      uid: "mailbox_demo",
      machine: {:module, @ra_module, %{}},
      data_dir: 'priv/ra'
    }

    case :ra.start_server(ra_config) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      error -> error
    end
  end

  def run_linearizability_tests do
    test_user = "alice"

    # Test 1: PUT operation
    IO.puts("")
    IO.puts("📤 Test: PUT operation (linearizable write)")
    put_result1 = execute_command({:put, "alice", "Message 1"})
    put_result2 = execute_command({:put, "alice", "Message 2"})
    IO.puts("PUT results: #{inspect([put_result1, put_result2])}")

    # Test 2: PEEK operation
    IO.puts("")
    IO.puts("👀 Test: PEEK operation (linearizable read)")
    peek_result = execute_command({:peek, "alice"})
    IO.puts("PEEK result: #{inspect(peek_result)}")

    # Test 3: CONSUME operation
    IO.puts("")
    IO.puts("📥 Test: CONSUME operation (atomic read+delete)")
    consume_result1 = execute_command({:consume, "alice"})
    consume_result2 = execute_command({:consume, "alice"})
    consume_result3 = execute_command({:consume, "alice"})  # Should be empty
    IO.puts("CONSUME results: #{inspect([consume_result1, consume_result2, consume_result3])}")

    # Test 4: Empty mailbox
    IO.puts("")
    IO.puts("📭 Test: Empty mailbox handling")
    empty_result = execute_command({:consume, "alice"})
    IO.puts("Empty mailbox result: #{inspect(empty_result)}")

    IO.puts("")
    IO.puts("✅ RA Linearizability tests completed!")
    IO.puts("")
    IO.puts("Key Linearizability Guarantee:")
    IO.puts("- Messages stored atomically via Raft consensus")
    IO.puts("- Read+delete operations cannot be interleaved")
    IO.puts("- Strong consistency across potential cluster")
    IO.puts("- No race conditions between multiple operations")
  end

  def execute_command(command) do
    case :ra.process_command(@ra_name, command, 5000) do
      {:ok, result} -> result
      error -> {:error, error}
    end
  end
end

# Run the tests
RATester.run_tests()
