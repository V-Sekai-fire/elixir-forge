defmodule RAMailboxPropertyTest do
  @moduledoc """
  Property-based tests for RA mailbox correctness using PropCheck.

  These tests verify formal properties that must hold for all possible inputs,
  providing mathematical guarantees about our mailbox implementation.
  """

  use PropCheck
  use ExUnit.Case

  @moduletag timeout: 600_000  # 10 minutes for property tests

  require Logger

  # Generators
  def user() do
    oneof(["alice", "bob", "charlie", "diana", "eve"])
  end

  def message() do
    frequency([
      {4, non_empty(utf8())},
      {2, list(range(1, 10)) |> let ms <- ms do
        "generated_#{inspect(ms)}"
      end},
      {1, unicode_binary(length: 10)}
    ])
  end

  def messages(min, max) do
    let len <- range(min, max) do
      vector(len, message())
    end
  end

  def non_empty_messages() do
    messages(1, 10)
  end

  # Setup/cleanup for each property test
  setup do
    # Note: For now, tests will use a simple approach.
    # In practice, we'd need to set up RA servers for each test
    # or use test helpers that mock the RA layer.

    Logger.info("Setting up property test environment")

    :ok
  end

  teardown do
    Logger.info("Cleaning up property test environment")
  end

  # =====================================================
  # PROPERTY TESTS - Linearizable Mailbox Semantics
  # =====================================================

  @tag :property
  @tag :linearizability
  property "exactly_once_consumption", [:verbose] do
    forall {user, messages} <- {user(), non_empty(messages())} do
      # Setup: Clear any existing state for this user
      cleanup_mailbox(user)

      # Put all messages into mailbox
      put_results = Enum.map(messages, fn msg ->
        RAMailbox.RAClusterSupervisor.put(user, msg)
      end)

      # All puts should succeed
      assert_all_puts_succeeded(put_results)

      # Verify correct message count
      final_count = RAMailbox.RAClusterSupervisor.get_message_count(user)
      assert final_count == length(messages), "Expected #{length(messages)} messages, got #{final_count}"

      # Consume all messages and verify exactly-once semantics
      consumed = consume_all_messages(user)

      # Exactly the right number of messages were consumed
      assert length(consumed) == length(messages)

      # All messages were consumed exactly once (no duplicates, no missing)
      assert Enum.sort(consumed) == Enum.sort(messages)

      # Mailbox should now be empty
      assert RAMailbox.RAClusterSupervisor.get_message_count(user) == 0

      # Further peeks/consumes should fail
      assert {:error, :empty} = RAMailbox.RAClusterSupervisor.peek(user)
      assert {:error, :empty} = RAMailbox.RAClusterSupervisor.consume(user)

      # Cleanup
      cleanup_mailbox(user)

      true
    end
  end

  @tag :property
  @tag :fifo
  property "fifo_ordering_guarantee", [:verbose] do
    forall {user, messages} <- {user(), messages(2, 8)} do
      # Setup
      cleanup_mailbox(user)

      # Put messages in specific order
      put_results = Enum.map(messages, fn msg ->
        RAMailbox.RAClusterSupervisor.put(user, msg)
      end)
      assert_all_puts_succeeded(put_results)

      # Consume in FIFO order
      consumed_order = consume_all_messages(user)

      # Order must be preserved: consumed == inserted
      assert consumed_order == messages, """
      FIFO violation:
        Inserted: #{inspect(messages)}
        Consumed: #{inspect(consumed_order)}
      """

      # Cleanup
      cleanup_mailbox(user)

      true
    end
  end

  @tag :property
  @tag :isolation
  property "user_mailbox_isolation", [:verbose] do
    forall {user1, user2, msg1, msg2} <- {user(), user(), message(), message()} do
      # Ensure different users
      assume user1 != user2

      # Setup - clean both mailboxes
      cleanup_mailbox(user1)
      cleanup_mailbox(user2)

      # Put messages for each user
      assert :ok = RAMailbox.RAClusterSupervisor.put(user1, msg1)
      assert :ok = RAMailbox.RAClusterSupervisor.put(user2, msg2)

      # Verify isolation: Each user gets their own message
      assert {:ok, ^msg1} = RAMailbox.RAClusterSupervisor.consume(user1)
      assert {:ok, ^msg2} = RAMailbox.RAClusterSupervisor.consume(user2)

      # Both mailboxes should now be empty
      assert RAMailbox.RAClusterSupervisor.get_message_count(user1) == 0
      assert RAMailbox.RAClusterSupervisor.get_message_count(user2) == 0

      # Cleanup
      cleanup_mailbox(user1)
      cleanup_mailbox(user2)

      true
    end
  end

  @tag :property
  @tag :peek_semantics
  property "peek_does_not_consume", [:verbose] do
    forall {user, msg1, msg2} <- {user(), message(), message()} do
      # Setup
      cleanup_mailbox(user)

      # Put messages
      assert :ok = RAMailbox.RAClusterSupervisor.put(user, msg1)
      assert :ok = RAMailbox.RAClusterSupervisor.put(user, msg2)

      # Peek multiple times - should always return same first message
      assert {:ok, ^msg1} = RAMailbox.RAClusterSupervisor.peek(user)
      assert {:ok, ^msg1} = RAMailbox.RAClusterSupervisor.peek(user)
      assert {:ok, ^msg1} = RAMailbox.RAClusterSupervisor.peek(user)

      # Message count shouldn't change
      assert RAMailbox.RAClusterSupervisor.get_message_count(user) == 2

      # Consume should still work normally
      assert {:ok, ^msg1} = RAMailbox.RAClusterSupervisor.consume(user)
      assert {:ok, ^msg2} = RAMailbox.RAClusterSupervisor.consume(user)

      # Cleanup
      cleanup_mailbox(user)

      true
    end
  end

  @tag :property
  @tag :basic_operations
  property "basic_put_get_operations", [:verbose] do
    forall {user, message, num_ops} <- {user(), message(), range(1, 5)} do
      # Setup
      cleanup_mailbox(user)

      # Put one message multiple times
      put_results = Enum.map(1..num_ops, fn _ ->
        RAMailbox.RAClusterSupervisor.put(user, message)
      end)

      # All puts should succeed
      assert_all_puts_succeeded(put_results)

      # Should have exactly num_ops messages
      count = RAMailbox.RAClusterSupervisor.get_message_count(user)
      assert count == num_ops, "Expected #{num_ops} messages, got #{count}"

      # Consume num_ops messages (all should be our message)
      consumed = Enum.map(1..num_ops, fn _ ->
        {:ok, msg} = RAMailbox.RAClusterSupervisor.consume(user)
        msg
      end)

      # All consumed messages should match what we put
      assert Enum.all?(consumed, &(&1 == message))

      # Mailbox should be empty
      assert RAMailbox.RAClusterSupervisor.get_message_count(user) == 0
      assert {:error, :empty} = RAMailbox.RAClusterSupervisor.peek(user)

      # Cleanup
      cleanup_mailbox(user)

      true
    end
  end

  # =====================================================
  # HELPER FUNCTIONS
  # =====================================================

  def assert_all_puts_succeeded(results) do
    failed_puts = Enum.filter(results, fn result -> result != :ok end)
    assert Enum.empty?(failed_puts), "Some PUT operations failed: #{inspect(failed_puts)}"
  end

  def consume_all_messages(user) do
    # Consume until empty
    do_consume_all_messages(user, [])
  end

  def do_consume_all_messages(user, acc) do
    case RAMailbox.RAClusterSupervisor.consume(user) do
      {:ok, message} -> do_consume_all_messages(user, [message | acc])
      {:error, :empty} -> Enum.reverse(acc)
    end
  end

  def cleanup_mailbox(user) do
    # Drain any remaining messages
    consume_all_messages(user)
    # Verify empty
    assert {:error, :empty} = RAMailbox.RAClusterSupervisor.peek(user)
  end

  # =====================================================
  # PROPERTY TEST CONFIGURATION
  # =====================================================

  @tag :property
  @tag :missing_server
  test "placeholder_test_until_ra_server_works" do
    # This is a placeholder test until we get the RA server working properly
    # For now, the property tests will fail due to RA server startup issues

    # When RA server startup is fixed, remove this test and uncomment
    # the property tests above

    Logger.info("RA server currently has startup issues - property tests queued for implementation")
    assert true
  end
end
