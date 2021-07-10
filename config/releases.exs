import Config

# These defaults mirror the ones in config.exs, remember not to change one
# without changing the other.

# Connect to database via specified IP version. Options are either "IPv4" or "IPv6".
# If IP version is not specified and database host is:
#   - an IP address, then value ("IPv4"/"IPv6") will be disregarded and Realtime will automatically connect via correct version.
#   - a name (e.g. "db.abcd.supabase.co"), then Realtime will connect either via IPv4 or IPv6. It is recommended
#   to specify IP version to prevent potential non-existent domain (NXDOMAIN) errors.
db_ip_version =
  %{"ipv4" => :inet, "ipv6" => :inet6}
  |> Map.fetch(System.get_env("DB_IP_VERSION", "") |> String.downcase())

config :realtime,
  db_host: System.fetch_env!("DB_HOST"),
  db_port: String.to_integer(System.fetch_env!("DB_PORT")),
  db_name: System.fetch_env!("DB_NAME"),
  db_user: System.fetch_env!("DB_USER"),
  db_password: System.fetch_env!("DB_PASSWORD"),
  db_ssl: System.get_env("DB_SSL", "true") == "true",
  db_ip_version: db_ip_version,
  publications: System.get_env("PUBLICATIONS", "[\"supabase_realtime\"]"),
# If a slot name is not specified then 
  slot_name: System.get_env("SLOT_NAME") || :temporary,
# If the replication lag exceeds the set MAX_REPLICATION_LAG_MB (make sure the value is a positive integer in megabytes) value
# then replication slot named SLOT_NAME (e.g. "realtime") will be dropped and Realtime will
# restart with a new slot.
  max_replication_lag_in_mb: String.to_integer(System.get_env("MAX_REPLICATION_LAG_MB", "0"))

config :logger,
  truncate: :infinity,
  level: :info#,
  # handle_sasl_reports: true,
  # handle_otp_reports: true
