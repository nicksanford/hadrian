defmodule Hadrian.Registry do
  @moduledoc """
  Local process storage for Hadrian instances.
  """

  @type role :: term()
  @type key :: Hadrian.name() | {Hadrian.name(), role()}
  @type value :: term()

  @doc false
  def child_spec(_arg) do
    [keys: :unique, name: __MODULE__]
    |> Registry.child_spec()
    |> Supervisor.child_spec(id: __MODULE__)
  end

  @doc """
  Fetch the config for an Hadrian supervisor instance.
  ## Example
  Get the default instance config:
      Hadrian.Registry.config(Hadrian)
  Get config for a custom named instance:
      Hadrian.Registry.config(MyApp.Hadrian)
  """
  @spec config(Hadrian.name()) :: Hadrian.Config.t()
  def config(hadrian_name) do
    case Registry.lookup(__MODULE__, hadrian_name) do
      [{_pid, config}] ->
        config

      _ ->
        raise RuntimeError,
              "no config registered for #{hadrian_name} instance, " <>
                "is the supervisor running?"
    end
  end

  @doc """
  Returns the pid of a supervised Hadrian process, or `nil` if the process can't be found.
  ## Example
  Get the Hadrian supervisor's pid:
      Hadrian.Registry.whereis(Hadrian)
  Get a supervised module's pid:
      Hadrian.Registry.whereis(Hadrian, Hadrian.Notifier)
  Get the pid for a plugin:
      Hadrian.Registry.whereis(Hadrian, {:plugin, MyApp.Hadrian.Plugin})
  Get the pid for a queue's producer:
      Hadrian.Registry.whereis(Hadrian, {:producer, :default})
  """
  @spec whereis(Hadrian.name(), role()) :: pid() | nil
  def whereis(hadrian_name, role \\ nil) do
    hadrian_name
    |> via(role)
    |> GenServer.whereis()
  end

  @doc """
  Build a via tuple suitable for calls to a supervised Hadrian process.
  ## Example
  For an Hadrian supervisor:
      Hadrian.Registry.via(Hadrian)
  For a supervised module:
      Hadrian.Registry.via(Hadrian, Hadrian.Notifier)
  For a plugin:
      Hadrian.Registry.via(Hadrian, {:plugin, Hadrian.Plugins.Cron})
  """
  @spec via(Hadrian.name(), role(), value()) :: {:via, Registry, {__MODULE__, key()}}
  def via(hadrian_name, role \\ nil, value \\ nil)
  def via(hadrian_name, role, nil), do: {:via, Registry, {__MODULE__, key(hadrian_name, role)}}
  def via(hadrian_name, role, value), do: {:via, Registry, {__MODULE__, key(hadrian_name, role), value}}

  defp key(hadrian_name, nil), do: hadrian_name
  defp key(hadrian_name, role), do: {hadrian_name, role}
end
