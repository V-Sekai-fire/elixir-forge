import Config

# Runtime configuration for production
if config_env() == :prod do
  # Database for CockroachDB
  config :livebook_nx, LivebookNx.Repo,
    username: System.get_env("COCKROACHDB_USER"),
    password: System.get_env("COCKROACHDB_PASSWORD"),
    database: "livebook_nx_prod",
    hostname: System.get_env("COCKROACHDB_HOST") || "cockroachdb-cluster",
    port: 26257,
    ssl: true,
    ssl_opts: [cacertfile: "/path/to/ca.crt"]

  # Oban queues for production
  config :livebook_nx, Oban,
    engine: Oban.Pro.Engines.Smart,
    queues: [
      default: String.to_integer(System.get_env("OBAN_DEFAULT_QUEUE") || "10"),
      zimage: String.to_integer(System.get_env("OBAN_ZIMAGE_QUEUE") || "2")
    ],
    repo: LivebookNx.Repo

  # SeaweedFS config
  config :livebook_nx, :seaweedfs,
    endpoint: System.get_env("SEAWEEDFS_ENDPOINT") || "http://seaweedfs-master:9333",
    access_key: System.get_env("SEAWEEDFS_ACCESS_KEY"),
    secret_key: System.get_env("SEAWEEDFS_SECRET_KEY")
end
