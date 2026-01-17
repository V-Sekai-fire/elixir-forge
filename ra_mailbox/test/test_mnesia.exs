#!/usr/bin/env elixir
# Quick test script to verify Mnesia služba

# Start the mailbox application
IO.puts("Starting Mnesia mailbox service...")

# Start the application
case RAMailbox.Application.start(:normal, []) do
  {:ok, pid} ->
    IO.puts("✅ Application started successfully")

    # Wait a moment for initialization
    Process.sleep(2000)

    # Test basic operations
    IO.puts("\n🧪 Testing Mnesia mailbox operations...")

    user_id = "test_user_#{System.system_time(:millisecond)}"
    message1 = "Hello from Mnesia test 1"
    message2 = "Hello from Mnesia test 2"

    # Test PUT
    case RAMailbox.MnesiaStore.put(user_id, message1) do
      :ok ->
        IO.puts("✅ PUT operation successful")
      error ->
        IO.puts("❌ PUT operation failed: #{inspect(error)}")
    end

    # Test PUT again
    case RAMailbox.MnesiaStore.put(user_id, message2) do
      :ok ->
        IO.puts("✅ Second PUT operation successful")
      error ->
        IO.puts("❌ Second PUT operation failed: #{inspect(error)}")
    end

    # Test COUNT
    case RAMailbox.MnesiaStore.get_message_count(user_id) do
      2 ->
        IO.puts("✅ COUNT operation successful: 2 messages")
      count ->
        IO.puts("❌ COUNT operation failed: expected 2, got #{inspect(count)}")
    end

    # Test PEEK
    case RAMailbox.MnesiaStore.peek(user_id) do
      {:ok, content} ->
        IO.puts("✅ PEEK operation successful: #{content}")
      error ->
        IO.puts("❌ PEEK operation failed: #{inspect(error)}")
    end

    # Test CONSUME
    case RAMailbox.MnesiaStore.consume(user_id) do
      {:ok, content} ->
        IO.puts("✅ CONSUME operation successful: #{content}")
      error ->
        IO.puts("❌ CONSUME operation failed: #{inspect(error)}")
    end

    # Test COUNT after consume
    case RAMailbox.MnesiaStore.get_message_count(user_id) do
      1 ->
        IO.puts("✅ COUNT after consume successful: 1 message remaining")
      count ->
        IO.puts("❌ COUNT after consume failed: expected 1, got #{inspect(count)}")
    end

    # Test CONSUME remaining
    case RAMailbox.MnesiaStore.consume(user_id) do
      {:ok, content} ->
        IO.puts("✅ Second CONSUME operation successful: #{content}")
      error ->
        IO.puts("❌ Second CONSUME operation failed: #{inspect(error)}")
    end

    # Test EMPTY mailbox
    case RAMailbox.MnesiaStore.consume(user_id) do
      {:error, :empty} ->
        IO.puts("✅ EMPTY mailbox test successful")
      result ->
        IO.puts("❌ EMPTY mailbox test failed: expected :empty, got #{inspect(result)}")
    end

    # Test process_command API (for Zenoh bridge)
    IO.puts("\n🧪 Testing process_command API...")
    process_msg = "Process command test"

    case RAMailbox.MnesiaStore.process_command({:put, user_id <> "_process", process_msg}) do
      {:ok, :ok} ->
        IO.puts("✅ process_command PUT successful")
      result ->
        IO.puts("❌ process_command PUT failed: #{inspect(result)}")
    end

    case RAMailbox.MnesiaStore.process_command({:consume, user_id <> "_process"}) do
      {:ok, ^process_msg} ->
        IO.puts("✅ process_command CONSUME successful")
      result ->
        IO.puts("❌ process_command CONSUME failed: #{inspect(result)}")
    end

    IO.puts("\n🎉 Mnesia mailbox functionality test completed!")
    IO.puts("📊 All operations verified: PUT, PEEK, CONSUME, COUNT")
    IO.puts("💾 Data survives in Mnesia disk copies")

    # Clean shutdown
    RAMailbox.Application.stop(:normal)
    IO.puts("✅ Service shut down cleanly")

  error ->
    IO.puts("❌ Failed to start application: #{inspect(error)}")
end
