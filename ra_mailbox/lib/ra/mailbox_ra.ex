defmodule RAMailbox.RA.MailboxRA do
  @moduledoc """
  RA server for linearizable mailbox operations.

  This RA server provides strongly consistent mailbox semantics:
  - put: Add message to user's mailbox queue
  - consume: Atomically read+delete next message (exactly-once)
  - peek: Linearizable read-only peek at next message
  """

  @type user_id :: String.t()
  @type message :: any()
  @type command :: {:put, user_id, message} | {:consume, user_id} | {:peek, user_id}

  @spec init(keyword) :: :ra.srv_config()
  def init(config) do
    # Initialize mailbox state
    Map.put(config, :mailboxes, %{})
  end

  @spec apply(:ra.srv_config(), command()) :: {:reply, any, :ra.srv_config()}
  def apply(state, {:put, user_id, message}) do
    # Add message to user's mailbox queue (atomic/linearizable)
    timestamp = System.monotonic_time()
    mailbox_message = %{message: message, timestamp: timestamp, id: make_ref()}

    new_state = update_in(state.mailboxes[user_id],
      fn queue -> [mailbox_message | queue || []] end)

    {:reply, :ok, new_state}
  end

  def apply(state, {:consume, user_id}) do
    # Linearizable read+delete (Atomic Pop for mailbox semantics)
    case state.mailboxes[user_id] do
      [message | rest] ->
        new_state = Map.update(state.mailboxes, user_id, [], fn _ -> rest end)
        {:reply, {:ok, message}, new_state}

      nil ->
        {:reply, {:error, :empty}, state}

      [] ->
        {:reply, {:error, :empty}, state}
    end
  end

  def apply(state, {:peek, user_id}) do
    # Linearizable read-only peek
    case state.mailboxes[user_id] do
      [message | _rest] ->
        {:reply, {:ok, message}, state}

      nil ->
        {:reply, {:error, :empty}, state}

      [] ->
        {:reply, {:error, :empty}, state}
    end
  end

  @spec get_mailbox_length(:ra.srv_config(), user_id) :: integer()
  def get_mailbox_length(state, user_id) do
    length(state.mailboxes[user_id] || [])
  end

  @spec get_all_users(:ra.srv_config()) :: [user_id]
  def get_all_users(state) do
    Map.keys(state.mailboxes)
  end
end
