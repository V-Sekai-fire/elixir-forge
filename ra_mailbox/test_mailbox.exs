#!/usr/bin/env elixir
# Test script for RA + Zenoh mailbox service
# Run with: elixir test_mailbox.exs

# Import dependencies (assumes in project root)
Mix.install([
  {:zenohex, "~> 0.7.2"},
  {:jason, "~> 1.4"}
])

defmodule MailboxTester do
  @zenoh_locator "tcp/127.0.0.1:7447"
  @test_user "test_user_#{System.system_time(:millisecond)}"

  def run_tests do
    IO.puts("🧪 RA + Zenoh Mailbox Service Test")
    IO.puts("==================================")

    # Open Zenoh session
    case Zenohex.open([locators: [@zenoh_locator]]) do
      {:ok, session} ->
        IO.puts("✅ Connected to Zenoh router")

        # Run test suite
        test_put_message(session)
        test_consume_message(session)
        test_peek_message(session)
        test_empty_mailbox(session)

        IO.puts("")
        IO.puts("🎉 Mailbox tests completed!")

        # Clean up
        Zenohex.Session.close(session)

      {:error, reason} ->
        IO.puts("❌ Failed to connect to Zenoh: #{inspect(reason)}")
        IO.puts("")
        IO.puts("📋 Setup Checklist:")
        IO.puts("  1. Start zenohd: systemctl --user start zenohd")
        IO.puts("  2. Check zenohd status: systemctl --user status zenohd")
        IO.puts("  3. Verify router listens on port 7447")
        IO.puts("  4. Start mailbox service: cd ra_mailbox && mix phoenix.server")
        System.stop(1)
    end
  end

  def test_put_message(session) do
    IO.puts("")
    IO.puts("📤 Test: PUT message to mailbox")

    message = %{text: "Hello from test #{@test_user}", time: DateTime.utc_now() |> DateTime.to_iso8601()}

    case put_message(session, @test_user, message) do
      :ok -> IO.puts("✅ Message put successfully")
      error ->
        IO.puts("❌ Put failed: #{inspect(error)}")
    end
  end

  def test_consume_message(session) do
    IO.puts("")
    IO.puts("📥 Test: CONSUME next message")

    case consume_message(session, @test_user) do
      {:ok, message} ->
        IO.puts("✅ Consumed message: #{inspect(message)}")

      {:error, :empty} ->
        IO.puts("✅ Mailbox empty (expected after consume)")

      error ->
        IO.puts("❌ Consume failed: #{inspect(error)}")
    end
  end

  def test_peek_message(session) do
    IO.puts("")
    IO.puts("👀 Test: PEEK next message (read without consume)")

    # First put a message back
    put_message(session, @test_user, %{text: "Peek test message"})

    # Now peek at it
    case peek_message(session, @test_user) do
      {:ok, message} ->
        IO.puts("✅ Peek successful: #{inspect(message)}")

        # Verify it's still there by peeking again
        case peek_message(session, @test_user) do
          {:ok, ^message} -> IO.puts("✅ Peek idempotent - message still there")
          _ -> IO.puts("⚠️  Peek not idempotent")
        end

      error ->
        IO.puts("❌ Peek failed: #{inspect(error)}")
    end
  end

  def test_empty_mailbox(session) do
    IO.puts("")
    IO.puts("📭 Test: Consume from empty mailbox")

    # Consume remaining messages to empty mailbox
    consume_message(session, @test_user)

    # Try to consume from empty mailbox
    case consume_message(session, @test_user) do
      {:error, :empty} -> IO.puts("✅ Empty mailbox handled correctly")
      {:ok, _msg} -> IO.puts("⚠️  Empty mailbox returned message (unexpected)")
      error -> IO.puts("❌ Unexpected error: #{inspect(error)}")
    end
  end

  # Helper functions for mailbox operations
  def put_message(session, user_id, message) do
    key_expr = "forge/mailbox/#{user_id}/put"

    case Zenohex.Session.declare_queryable(session, key_expr) do
      {:ok, queryable} ->
        payload = Jason.encode!(message)

        # Send PUT request
        Zenohex.Queryable.loop(queryable, fn query ->
          Zenohex.Query.payload(query) |> IO.inspect(label: "PUT query payload")
          Zenohex.Query.reply(query, key_expr, payload)
          :stop
        end)

        :ok

      {:error, reason} -> {:error, reason}
    end
  end

  def consume_message(session, user_id) do
    key_expr = "forge/mailbox/#{user_id}/consume"

    case Zenohex.Session.declare_queryable(session, key_expr) do
      {:ok, queryable} ->
        result = Zenohex.Queryable.loop(queryable, fn query ->
          # Block waiting for reply
          :timer.sleep(100) # Small timeout
          {:ok, reply} = Zenohex.Query.payload(query)

          case Jason.decode(reply) do
            {:ok, %{"status" => "success", "result" => result}} -> {:ok, result}
            {:ok, %{"status" => "error", "reason" => reason}} -> {:error, reason}
            _ -> {:error, "Invalid response format"}
          end
        end)

        result

      {:error, reason} -> {:error, reason}
    end
  end

  def peek_message(session, user_id) do
    key_expr = "forge/mailbox/#{user_id}/peek"

    case Zenohex.Session.declare_queryable(session, key_expr) do
      {:ok, queryable} ->
        Zenohex.Queryable.loop(queryable, fn query ->
          case Zenohex.Query.payload(query) do
            {:ok, reply} ->
              case Jason.decode(reply) do
                {:ok, %{"status" => "success", "result" => result}} -> {:ok, result}
                {:ok, %{"status" => "error", "reason" => reason}} -> {:error, reason}
              end
            _ -> {:error, "No reply"}
          end
        end)

      {:error, reason} -> {:error, reason}
    end
  end
end

# Run the tests
MailboxTester.run_tests()
