defmodule Forge.Repo.Migrations.CreateObanTables do
  use Ecto.Migration

  def change do
    # Create Oban jobs table (SQLite compatible)
    execute """
    CREATE TABLE oban_jobs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      state TEXT NOT NULL CHECK(length(state) > 0),
      queue TEXT NOT NULL DEFAULT 'default' CHECK(length(queue) > 0 AND length(queue) < 128),
      worker TEXT NOT NULL CHECK(length(worker) > 0 AND length(worker) < 128),
      args TEXT NOT NULL DEFAULT '{}',
      errors TEXT NOT NULL DEFAULT '[]',
      attempt INTEGER NOT NULL DEFAULT 0 CHECK(attempt >= 0),
      max_attempts INTEGER NOT NULL DEFAULT 20,
      inserted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      scheduled_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      attempted_at DATETIME,
      completed_at DATETIME,
      attempted_by TEXT,
      discarded_at DATETIME,
      priority INTEGER NOT NULL DEFAULT 0 CHECK(priority >= 0 AND priority <= 3),
      tags TEXT NOT NULL DEFAULT '{}',
      meta TEXT NOT NULL DEFAULT '{}',
      cancelled_at DATETIME
    );
    """

    # Create indexes for Oban
    execute "CREATE INDEX oban_jobs_state_queue_priority_scheduled_at_id_idx ON oban_jobs (state, queue, priority, scheduled_at, id);"
    execute "CREATE INDEX oban_jobs_scheduled_at_id_idx ON oban_jobs (scheduled_at, id) WHERE state = 'scheduled';"
  end
end
