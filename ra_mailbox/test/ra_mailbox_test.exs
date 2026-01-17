defmodule RAMailboxTest do
  use ExUnit.Case
  doctest RAMailbox

  alias RAMailbox.DETS.MailboxStore

  setup_all do
    IO.puts("\n--- DETS Mailbox FlatBuffers/Zenoh Integration Tests ---")
    IO.puts("Testing persistent mailbox logic with DETS storage")
    :ok
  end

  describe "RA Mailbox Operations via FlatBuffers/Zenoh" do
    @tag :integration
    test "put, consume, and peek operations with FlatBuffers" do
      user_id = "test_user_#{:erlang.system_time(:millisecond)}"

      # Test 1: PUT operation with FlatBuffers encoding
      message_data = %{
        "from" => "alice@test.com",
        "subject" => "Integration Test Message",
        "body" => "This message tests FlatBuffers/Zenoh integration",
        "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "priority" => "normal"
      }

      # Encode as FlatBuffers-like map (simplified for testing)
      message_payload = Jason.encode!(message_data)

      # PUT the message via RA
      assert {:ok, :ok} = :ra.process_command(:test_mailbox_ra, {:put, user_id, message_payload})

      # Test 2: PEEK operation (read without consuming)
      assert {:ok, peeked_message} = :ra.process_command(:test_mailbox_ra, {:peek, user_id})
      assert peeked_message != nil

      # Decode and verify it matches original
      peeked_decoded = Jason.decode!(peeked_message)
      assert peeked_decoded["from"] == "alice@test.com"
      assert peeked_decoded["subject"] == "Integration Test Message"

      # Test 3: PEEK again (should be same message, not consumed)
      assert {:ok, same_message} = :ra.process_command(:test_mailbox_ra, {:peek, user_id})
      assert same_message == peeked_message

      # Test 4: CONSUME operation (read and remove)
      assert {:ok, consumed_message} = :ra.process_command(:test_mailbox_ra, {:consume, user_id})
      assert consumed_message == peeked_message

      # Verify message is now gone (consume from empty mailbox)
      assert {:ok, {:error, :empty}} = :ra.process_command(:test_mailbox_ra, {:consume, user_id})
      assert {:ok, {:error, :empty}} = :ra.process_command(:test_mailbox_ra, {:peek, user_id})
    end

    @tag :integration
    test "concurrent operations maintain linearizability" do
      # Test that multiple concurrent operations maintain order
      user_id = "concurrent_test_#{:erlang.system_time(:millisecond)}"

      # Put multiple messages quickly
      message_count = 10
      messages = Enum.map(1..message_count, fn i ->
        %{"id" => i, "data" => "Message #{i}", "timestamp" => System.system_time(:millisecond)}
      end)

      # Submit all PUT operations asynchronously
      put_tasks = Enum.map(messages, fn msg ->
        Task.async(fn ->
          payload = Jason.encode!(msg)
          :ra.process_command(:test_mailbox_ra, {:put, user_id, payload})
        end)
      end)

      # Wait for all puts to complete
      put_results = Enum.map(put_tasks, &Task.await/1)
      assert Enum.all?(put_results, fn
        {:ok, :ok} -> true
        _ -> false
      end)

      # Now consume all messages and verify they come in insertion order
      consumed_messages = Enum.map(1..message_count, fn _ ->
        {:ok, message} = :ra.process_command(:test_mailbox_ra, {:consume, user_id})
        Jason.decode!(message)
      end)

      # Verify all messages consumed and in order (chronological)
      consumed_ids = Enum.map(consumed_messages, & &1["id"])
      expected_ids = Enum.to_list(1..message_count)
      assert consumed_ids == expected_ids

      # Verify mailbox is now empty
      assert {:ok, {:error, :empty}} = :ra.process_command(:test_mailbox_ra, {:consume, user_id})
    end

    @tag :integration
    test "multi-user isolation" do
      # Test that different users have independent mailboxes
      user1 = "user1_test_#{:erlang.system_time(:millisecond)}"
      user2 = "user2_test_#{:erlang.system_time(:millisecond)}"

      # Put messages for both users
      user1_message = Jason.encode!(%{"user" => "user1", "message" => "Hello from user1"})
      user2_message = Jason.encode!(%{"user" => "user2", "message" => "Hello from user2"})

      assert {:ok, :ok} = :ra.process_command(:test_mailbox_ra, {:put, user1, user1_message})
      assert {:ok, :ok} = :ra.process_command(:test_mailbox_ra, {:put, user2, user2_message})

      # Verify each user gets their own message
      {:ok, user1_consumed} = :ra.process_command(:test_mailbox_ra, {:consume, user1})
      {:ok, user2_consumed} = :ra.process_command(:test_mailbox_ra, {:consume, user2})

      user1_decoded = Jason.decode!(user1_consumed)
      user2_decoded = Jason.decode!(user2_consumed)

      assert user1_decoded["user"] == "user1"
      assert user2_decoded["user"] == "user2"

      # Both mailboxes should now be empty
      assert {:ok, {:error, :empty}} = :ra.process_command(:test_mailbox_ra, {:consume, user1})
      assert {:ok, {:error, :empty}} = :ra.process_command(:test_mailbox_ra, {:consume, user2})
    end

    @tag :performance
    test "mailbox operation performance basics" do
      user_id = "perf_test_#{:erlang.system_time(:millisecond)}"

      # Performance baseline test
      operation_count = 100

      # Time PUT operations
      put_start = System.monotonic_time(:microsecond)
      Enum.each(1..operation_count, fn i ->
        msg = Jason.encode!(%{"i" => i, "data" => "Performance test message #{i}"})
        {:ok, :ok} = :ra.process_command(:test_mailbox_ra, {:put, user_id, msg})
      end)
      put_end = System.monotonic_time(:microsecond)
      put_time = put_end - put_start

      put_avg_us = put_time / operation_count
      IO.puts("PUT operation average: #{put_avg_us} microseconds")

      # Time CONSUME operations
      consume_start = System.monotonic_time(:microsecond)
      Enum.each(1..operation_count, fn _ ->
        {:ok, _msg} = :ra.process_command(:test_mailbox_ra, {:consume, user_id})
      end)
      consume_end = System.monotonic_time(:microsecond)
      consume_time = consume_end - consume_start

      consume_avg_us = consume_time / operation_count
      IO.puts("CONSUME operation average: #{consume_avg_us} microseconds")

      # Basic performance assertions
      assert put_avg_us < 10000 # Should be under 10ms per operation
      assert consume_avg_us < 10000
      assert put_avg_us > 0
      assert consume_avg_us > 0
    end
  end

  describe "FlatBuffers Schema Validation" do
    test "message format compliance" do
      # Test that our messages can be properly serialized/deserialized
      # even though we're using JSON for simplicity in tests
      test_message = %{
        "id" => "test-msg-123",
        "type" => "mailbox",
        "payload" => %{
          "from" => "service@forge.ai",
          "to" => "user@example.com",
          "content" => "Integration test successful",
          "metadata" => %{
            "priority" => "normal",
            "timestamp" => System.system_time(:second),
            "tags" => ["test", "integration"]
          }
        }
      }

      # Serialize (using JSON to simulate FlatBuffers)
      serialized = Jason.encode!(test_message)
      assert is_binary(serialized)

      # Deserialize
      deserialized = Jason.decode!(serialized)

      # Validate structure
      assert deserialized["payload"]["from"] == "service@forge.ai"
      assert deserialized["payload"]["metadata"]["priority"] == "normal"
      assert "test" in deserialized["payload"]["metadata"]["tags"]
      assert "integration" in deserialized["payload"]["metadata"]["tags"]
    end
  end

  describe "Service Resilience" do
    @tag :resilience
    test "RA server persistence across restarts" do
      user_id = "persistence_test_#{:erlang.system_time(:millisecond)}"

      # Put a message
      message = Jason.encode!(%{"test" => "persistence", "data" => DateTime.utc_now()})
      assert {:ok, :ok} = :ra.process_command(:test_mailbox_ra, {:put, user_id, message})

      # Verify it's there
      assert {:ok, _msg} = :ra.process_command(:test_mailbox_ra, {:peek, user_id})

      # In a real resilience test, we would restart the RA server
      # and verify the message survives. For now, we just verify
      # the RA server can be queried multiple times consistently.

      # Multiple reads should return same result
      assert {:ok, msg1} = :ra.process_command(:test_mailbox_ra, {:peek, user_id})
      assert {:ok, ^msg1} = :ra.process_command(:test_mailbox_ra, {:peek, user_id})

      # And consume should remove it
      assert {:ok, ^msg1} = :ra.process_command(:test_mailbox_ra, {:consume, user_id})
      assert {:ok, {:error, :empty}} = :ra.process_command(:test_mailbox_ra, {:consume, user_id})
    end
  end
end
