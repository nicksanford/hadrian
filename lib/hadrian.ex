defmodule Hadrian do
  use Supervisor
  alias Hadrian.Adapters.Changes.Transaction
  alias Hadrian.Adapters.Postgres.EpgsqlServer
  alias Hadrian.{Config, Registry, Replication}

  @type notify_callback :: (%Transaction{} -> :ok)
  @type publication :: String.t()
  @type slot_name :: String.t()
  # https://www.postgresql.org/docs/current/datatype-pg-lsn.html#:~:text=This%20type%20is%20a%20representation,for%20example%2C%2016%2FB374D848%20.
  # These are 2 32 bit integers encoded in hex
  # https://pgpedia.info/x/xlogrecptr.html
  @type wal_position :: {String.t(), String.t()}
  @type max_replication_lag_in_mb :: non_neg_integer()
  @type host :: String.t()
  @type username :: String.t()
  @type database :: String.t()
  @type db_port :: non_neg_integer()
  @type ssl :: boolean()
  @type password :: String.t()
  @type ip_version :: :ipv4 | :ipv6
  @type name :: Supervisor.name()
  @type option ::
          {:notify_callback, notify_callback}
          | {:publications, [publication]}
          | {:slot_name, slot_name}
          | {:wal_position, wal_position}
          | {:max_replication_lag_in_mb, max_replication_lag_in_mb}
          | {:host, host}
          | {:username, username}
          | {:database, database}
          | {:port, db_port}
          | {:ssl, ssl}
          | {:password, password}
          | {:ip_version, ip_version}
          | {:name, name}

  @spec start_link([option()]) :: Supervisor.on_start()
  def start_link(opts) when is_list(opts) do
    conf = Config.new(opts)

    Supervisor.start_link(__MODULE__, conf, name: conf.name)
  end

  # @spec child_spec([option]) :: Supervisor.child_spec()
  # def child_spec(opts) do
  #   opts
  #   |> super()
  #   |> Supervisor.child_spec(id: Keyword.get(opts, :name, __MODULE__))
  # end

  @impl Supervisor
  def init(%Config{name: name} = conf) do
    # List all child processes to be supervised
    children = [
      {Replication, conf: conf, name: Registry.via(name, Replication)},
      {EpgsqlServer, conf: conf, name: Registry.via(name, EpgsqlServer)}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
