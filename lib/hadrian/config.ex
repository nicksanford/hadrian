defmodule Hadrian.Config do
  @moduledoc """
  The Config struct validates and encapsulates Hadrian instance state.

  Typically, you won't use the Config module directly. Hadrian automatically creates a Config struct
  on initialization and passes it through to all supervised children with the `:conf` key.
  """

  @non_empty_string_vals [:slot_name]
  @string_vals [:host, :username, :database, :password]
  @string_list_vals [:publications]
  @boolean_vals [:ssl]
  @non_neg_int_vals [:max_replication_lag_in_mb, :port]
  @enforce_keys [
    :notify_callback,
    :host,
    :username,
    :database,
    :port,
    :ssl,
    :ip_version,
    :publications,
    :slot_name,
    :wal_position,
    :max_replication_lag_in_mb,
    :name
  ]
  defstruct @enforce_keys ++ [:password]

  @type t :: %__MODULE__{
          notify_callback: Hadrian.notify_callback(),
          host: Hadrian.host(),
          username: Hadrian.username(),
          database: Hadrian.database(),
          port: Hadrian.db_port(),
          ssl: Hadrian.ssl(),
          password: Hadrian.password(),
          ip_version: Hadrian.ip_version(),
          publications: Hadrian.publication(),
          slot_name: Hadrian.slot_name(),
          wal_position: Hadrian.wal_position(),
          max_replication_lag_in_mb: Hadrian.max_replication_lag_in_mb()
        }
  @spec new([Hadrian.option()]) :: t()
  def new(raw_opts) when is_list(raw_opts) do
    opts = raw_opts |> normalize()
    validate!(opts)
    struct!(__MODULE__, opts)
  end

  def to_epgsql_config(%__MODULE__{} = config) do
    config
    |> Map.take([:host, :username, :database, :passwod, :port, :ssl])
    |> Enum.map(fn
      {k = :host, v} when is_binary(v) -> {k, String.to_charlist(v)}
      {k, v} -> {k, v}
    end)
    |> Enum.concat(maybe_add_tcp_opts(config))
    |> Enum.into(%{})
  end

  defp maybe_add_tcp_opts(%__MODULE__{
         host: host,
         ip_version: ip_version
       }) do
    with true <- not is_nil(ip_version),
         {:error, :einval} <- :inet.parse_address(host) do
      # only add :tcp_opts to epgsql_params when ip_version is present and host
      # is not an IP address.
      [tcp_opts: [Map.fetch!(%{ipv4: :inet, ipv6: :inet6}, ip_version)]]
    else
      _ -> []
    end
  end

  defp validate!(opts) do
    opts
    |> Enum.reduce_while(:ok, fn opt, acc ->
      case validate_opt(opt) do
        :ok -> {:cont, acc}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> then(fn
      :ok -> :ok
      {:error, reason} -> raise(ArgumentError, reason)
    end)
  end

  defp normalize(opts) do
    opts
    |> Keyword.update(:name, __MODULE__, & &1)
  end

  defp validate_opt(pair = {key, opt}) when key in @string_vals do
    if is_binary(opt) do
      :ok
    else
      format_error(pair, "be a string")
    end
  end

  defp validate_opt(pair = {key, opt}) when key in @non_empty_string_vals do
    if is_binary(opt) and opt != "" do
      :ok
    else
      format_error(pair, "be a non empty string")
    end
  end

  defp validate_opt(pair = {key, opt}) when key in @string_list_vals do
    if is_list(opt) and Enum.all?(opt, &is_binary/1) and length(opt) > 0 do
      :ok
    else
      format_error(pair, "be a non empty list of strings")
    end
  end

  defp validate_opt(pair = {key, opt}) when key in @boolean_vals do
    if is_boolean(opt) do
      :ok
    else
      format_error(pair, "be a boolean")
    end
  end

  defp validate_opt({key, opt} = pair) when key in @non_neg_int_vals do
    if is_integer(opt) and opt >= 0 do
      :ok
    else
      format_error(pair, "be a non negative integer")
    end
  end

  defp validate_opt({:ip_version, opt} = pair) do
    if opt in [:ipv4, :ipv6] do
      :ok
    else
      format_error(pair, "be either :ipv4 or :ipv6")
    end
  end

  defp validate_opt({:notify_callback, opt} = pair) do
    if is_function(opt, 1) do
      :ok
    else
      format_error(pair, "be a single arity function")
    end
  end

  defp validate_opt({:wal_position, opt} = pair) do
    opt
    |> then(fn
      {xlogid, xrecoff} when is_binary(xlogid) and is_binary(xrecoff) ->
        :ok

      _ ->
        format_error(
          pair,
          "be a 2 tuple containing hex strings which represent the pg_lsn type.\nE.g. {\"0\", \"0\"} to use default postgres replecation slot default"
        )
    end)
  end

  defp validate_opt({:name, _}), do: :ok

  defp validate_opt(opt) do
    {:error, "unknown option pair provided #{inspect(opt)}"}
  end

  defp format_error({key, opt}, msg) do
    {:error, "expected #{key} to #{msg}, instead got #{inspect(opt)}"}
  end
end
