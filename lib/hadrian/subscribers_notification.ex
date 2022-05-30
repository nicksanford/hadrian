defmodule Hadrian.SubscribersNotification do
  require Logger

  alias Hadrian.Adapters.Changes.Transaction

  def notify(%Transaction{changes: changes}) when is_list(changes) do
    changes
    |> IO.inspect()
    |> then(fn json -> Logger.info(json <> "\nlength: #{length(changes)}") end)
  end
end
