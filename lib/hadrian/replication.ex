# This file draws heavily from https://github.com/cainophile/cainophile
# License: https://github.com/cainophile/cainophile/blob/master/LICENSE

defmodule Hadrian.Replication do
  use GenServer

  alias Hadrian.Config
  alias Hadrian.Registry

  alias Hadrian.Adapters.Changes.{
    DeletedRecord,
    NewRecord,
    Transaction,
    TruncatedRelation,
    UpdatedRecord
  }

  alias Hadrian.Adapters.Postgres.Decoder

  alias Decoder.Messages.{
    Begin,
    Commit,
    Delete,
    Insert,
    Relation,
    Truncate,
    Type,
    Update
  }

  alias EpgsqlServer

  require Logger

  defmodule State do
    @enforce_keys [:conf]
    defstruct @enforce_keys ++
                [
                  relations: %{},
                  transaction: nil,
                  types: %{}
                ]
  end

  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)

    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts), do: {:ok, struct!(State, opts)}

  @impl true
  def handle_info({:epgsql, _pid, {:x_log_data, _start_lsn, _end_lsn, binary_msg}}, state) do
    decoded = Decoder.decode_message(binary_msg)

    Logger.debug("Received binary message: #{inspect(binary_msg, limit: :infinity)}")

    Logger.debug("Decoded message: " <> inspect(decoded, limit: :infinity))

    {:noreply, process_message(decoded, state)}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug(inspect(msg))
    {:noreply, state}
  end

  defp process_message(%Begin{final_lsn: final_lsn, commit_timestamp: commit_timestamp}, state) do
    %State{
      state
      | transaction: {final_lsn, %Transaction{changes: [], commit_timestamp: commit_timestamp}}
    }
  end

  # This will notify subscribers once the transaction has completed
  # FYI: this will be the last function called before returning to the client
  defp process_message(
         %Commit{lsn: commit_lsn, end_lsn: end_lsn},
         %State{
           conf: %Config{name: name, notify_callback: notify_callback},
           transaction: {current_txn_lsn, %Transaction{changes: changes} = txn},
           relations: relations
         } = state
       )
       when commit_lsn == current_txn_lsn do
    # To show how the updated columns look like before being returned
    # Feel free to delete after testing
    Logger.debug("Final Update of Columns " <> inspect(relations, limit: :infinity))

    complete_transaction = %{txn | changes: Enum.reverse(changes)}
    # Note currently this assumes that the nofification function
    # always succeeds i.e. returns `:ok`.
    #
    # Once nofication succeeds, the transaction is acked allowing
    # it to be removed from the WAL.
    #
    # If it returns anything other than `:ok` the replication genserver
    # dies & the transaction is not acked. This means that transaction
    # will be replayed when the next replication genserver boots.
    #
    # If this happens 3 times in 5 min the entire app crashes.
    #
    # If running in docker the container could then be rebooted by the
    # container scheduler.
    :ok = notify_callback.(complete_transaction)
    :ok = EpgsqlServer.acknowledge_lsn(Registry.via(name, EpgsqlServer), end_lsn)

    %{state | transaction: nil}
  end

  # Any unknown types will now be populated into state.types
  # This will be utilised later on when updating unidentified data types
  defp process_message(%Type{} = msg, state) do
    %{state | types: Map.put(state.types, msg.id, msg.name)}
  end

  defp process_message(%Relation{} = msg, state) do
    updated_columns =
      Enum.map(msg.columns, fn message ->
        if Map.has_key?(state.types, message.type) do
          %{message | type: state.types[message.type]}
        else
          message
        end
      end)

    updated_relations = %{msg | columns: updated_columns}

    %{state | relations: Map.put(state.relations, msg.id, updated_relations)}
  end

  defp process_message(
         %Insert{relation_id: relation_id, tuple_data: tuple_data},
         %State{
           transaction: {lsn, %{commit_timestamp: commit_timestamp, changes: changes} = txn},
           relations: relations
         } = state
       )
       when is_map(relations) do
    case Map.fetch(relations, relation_id) do
      {:ok, %{columns: columns, namespace: namespace, name: name}} when is_list(columns) ->
        data = data_tuple_to_map(columns, tuple_data)

        new_record = %NewRecord{
          type: "INSERT",
          schema: namespace,
          table: name,
          columns: columns,
          record: data,
          commit_timestamp: commit_timestamp
        }

        %State{state | transaction: {lsn, %{txn | changes: [new_record | changes]}}}

      _ ->
        state
    end
  end

  defp process_message(
         %Update{
           relation_id: relation_id,
           old_tuple_data: old_tuple_data,
           tuple_data: tuple_data
         },
         %State{
           relations: relations,
           transaction: {lsn, %{commit_timestamp: commit_timestamp, changes: changes} = txn}
         } = state
       )
       when is_map(relations) do
    case Map.fetch(relations, relation_id) do
      {:ok, %{columns: columns, namespace: namespace, name: name}} when is_list(columns) ->
        old_data = data_tuple_to_map(columns, old_tuple_data)
        data = data_tuple_to_map(columns, tuple_data)

        updated_record = %UpdatedRecord{
          type: "UPDATE",
          schema: namespace,
          table: name,
          columns: columns,
          old_record: old_data,
          record: data,
          commit_timestamp: commit_timestamp
        }

        %State{
          state
          | transaction: {lsn, %{txn | changes: [updated_record | changes]}}
        }

      _ ->
        state
    end
  end

  defp process_message(
         %Delete{
           relation_id: relation_id,
           old_tuple_data: old_tuple_data,
           changed_key_tuple_data: changed_key_tuple_data
         },
         %State{
           relations: relations,
           transaction: {lsn, %{commit_timestamp: commit_timestamp, changes: changes} = txn}
         } = state
       )
       when is_map(relations) do
    case Map.fetch(relations, relation_id) do
      {:ok, %{columns: columns, namespace: namespace, name: name}} when is_list(columns) ->
        data = data_tuple_to_map(columns, old_tuple_data || changed_key_tuple_data)

        deleted_record = %DeletedRecord{
          type: "DELETE",
          schema: namespace,
          table: name,
          columns: columns,
          old_record: data,
          commit_timestamp: commit_timestamp
        }

        %State{state | transaction: {lsn, %{txn | changes: [deleted_record | changes]}}}

      _ ->
        state
    end
  end

  defp process_message(
         %Truncate{truncated_relations: truncated_relations},
         %State{
           relations: relations,
           transaction: {lsn, %{commit_timestamp: commit_timestamp, changes: changes} = txn}
         } = state
       )
       when is_list(truncated_relations) and is_list(changes) and is_map(relations) do
    new_changes =
      Enum.reduce(truncated_relations, changes, fn truncated_relation, acc ->
        case Map.fetch(relations, truncated_relation) do
          {:ok, %{namespace: namespace, name: name}} ->
            [
              %TruncatedRelation{
                type: "TRUNCATE",
                schema: namespace,
                table: name,
                commit_timestamp: commit_timestamp
              }
              | acc
            ]

          _ ->
            acc
        end
      end)

    %State{
      state
      | transaction: {lsn, %{txn | changes: new_changes}}
    }
  end

  defp process_message(_msg, state) do
    state
  end

  defp data_tuple_to_map(columns, tuple_data) when is_list(columns) and is_tuple(tuple_data) do
    columns
    |> Enum.with_index()
    |> Enum.reduce_while(%{}, fn {column_map, index}, acc ->
      case column_map do
        %Relation.Column{name: column_name, type: column_type}
        when is_binary(column_name) and is_binary(column_type) ->
          try do
            val =
              tuple_data
              |> Kernel.elem(index)
              |> convert_column_record(column_type)

            {:cont, Map.put(acc, column_name, val)}
          rescue
            ArgumentError -> {:halt, acc}
          end

        _ ->
          {:cont, acc}
      end
    end)
  end

  defp data_tuple_to_map(_columns, _tuple_data), do: %{}

  defp convert_column_record(record, "timestamp") when is_binary(record) do
    with {:ok, %NaiveDateTime{} = naive_date_time} <- Timex.parse(record, "{RFC3339}"),
         %DateTime{} = date_time <- Timex.to_datetime(naive_date_time) do
      DateTime.to_iso8601(date_time)
    else
      _ -> record
    end
  end

  defp convert_column_record(record, "timestamptz") when is_binary(record) do
    case Timex.parse(record, "{RFC3339}") do
      {:ok, %DateTime{} = date_time} -> DateTime.to_iso8601(date_time)
      _ -> record
    end
  end

  defp convert_column_record(record, _column_type) do
    record
  end
end
