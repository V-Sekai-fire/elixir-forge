#!/usr/bin/env elixir

# Simple test to verify Mnesia can startup and basic operations work
IO.puts("Mnesia Standalone Test")

# Start Mnesia manually
case :application.ensure_started(:mnesia) do
  :ok ->
    IO.puts("✅ Mnesia started successfully")

    # Create schema
    case :mnesia.create_schema([node()]) do
      :ok -> IO.puts("✅ Schema created")
      {:error, {_, {:already_exists, _}}} -> IO.puts("📝 Schema exists")
      err -> IO.puts("❌ Schema error: #{inspect(err)}")
    end

    # Start Mnesia
    case :mnesia.start() do
      :ok -> IO.puts("✅ Mnesia running")
      err -> IO.puts("❌ Start error: #{inspect(err)}")
    end

    # Create table
    case :mnesia.create_table(:test_mailbox, [disc_copies: [node()]]) do
      {:atomic, :ok} -> IO.puts("✅ Table created")
      {:aborted, {:already_exists, _}} -> IO.puts("📝 Table exists")
      err -> IO.puts("❌ Table error: #{inspect(err)}")
    end

    # Wait for table
    case :mnesia.wait_for_tables([:test_mailbox], 5000) do
      :ok -> IO.puts("✅ Table ready")
      err -> IO.puts("❌ Wait error: #{inspect(err)}")
    end

    # Test basic operation
    :mnesia.transaction(fn ->
      :mnesia.write({:test_mailbox, {"test_user", 1}, {"Hello Mnesia", DateTime.utc_now()}})
    end)

    result = :mnesia.transaction(fn ->
      :mnesia.read({:test_mailbox, {"test_user", 1}})
    end)

    case result do
      {:atomic, [{_, {_user, _id}, {message, _time}}]} ->
        IO.puts("✅ Read operation successful: #{message}")
      err ->
        IO.puts("❌ Read error: #{inspect(err)}")
    end

    IO.puts("🎉 Basic Mnesia functionality verified!")

  err ->
    IO.puts("❌ Failed to start Mnesia: #{inspect(err)}")
end
