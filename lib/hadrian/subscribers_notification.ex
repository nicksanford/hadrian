defmodule Hadrian.SubscribersNotification do
  alias Hadrian.Adapters.Changes.Transaction
  require Logger

  def notify(%Transaction{changes: changes}) when is_list(changes) do
    changes
    |> inspect()
    |> then(fn json -> Logger.info(json <> "\nlength: #{length(changes)}") end)
  end
end
