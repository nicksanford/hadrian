defmodule Realtime.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger, warn: false

  def start(_type, _args) do
    # Use a named replication slot if you want realtime to pickup from where
    # it left after a restart because of, for example, a crash.
    # This will always be converted to lower-case.
    # You can get a list of active replication slots with
    # `select * from pg_replication_slots`
    slot_name = Application.get_env(:realtime, :slot_name)

    max_replication_lag_in_mb = Application.fetch_env!(:realtime, :max_replication_lag_in_mb)

    publications = Application.fetch_env!(:realtime, :publications) |> Jason.decode!()

    epgsql_params = %{
      host: ~c(#{Application.fetch_env!(:realtime, :db_host)}),
      username: Application.fetch_env!(:realtime, :db_user),
      database: Application.fetch_env!(:realtime, :db_name),
      port: Application.fetch_env!(:realtime, :db_port),
      ssl: Application.fetch_env!(:realtime, :db_ssl)
    }

    # epgsql_params = with password when is_binary(password) <- Application.get_env(:realtime, :db_password) do
    #   %{epgsql_params | password: password}
    # else
    #   _ ->
    #     epgsql_params
    # end

    epgsql_params =
      with {:ok, ip_version} <- Application.fetch_env!(:realtime, :db_ip_version),
           {:error, :einval} <- :inet.parse_address(epgsql_params.host) do
        # only add :tcp_opts to epgsql_params when ip_version is present and host
        # is not an IP address.
        Map.put(epgsql_params, :tcp_opts, [ip_version])
      else
        _ -> epgsql_params
      end

    # List all child processes to be supervised
    children = [
      {
        Realtime.DatabaseReplicationSupervisor,
        # You can provide a different WAL position if desired, or default to
        # allowing Postgres to send you what it thinks you need
        replication_config: [notify_func: &Realtime.SubscribersNotification.notify/1],
        epgsql_params: epgsql_params,
        publications: publications,
        slot_name: slot_name,
        wal_position: {"0", "0"},
        max_replication_lag_in_mb: max_replication_lag_in_mb
      }
    ]

    opts = [strategy: :one_for_one]
    Supervisor.start_link(children, opts)
  end
end
