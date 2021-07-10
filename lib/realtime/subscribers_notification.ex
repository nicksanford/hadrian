defmodule Realtime.SubscribersNotification do
  require Logger

  alias Realtime.Adapters.Changes.Transaction

  def notify(%Transaction{changes: changes}) when is_list(changes) do
    changes
    |> Jason.encode!(pretty: true)
    |> then(fn json -> Logger.info(json <> "\nlength: #{length(changes)}") end)
  end
end
