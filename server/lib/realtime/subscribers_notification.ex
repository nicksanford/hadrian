defmodule Realtime.SubscribersNotification do
  require Logger

  alias Realtime.Adapters.Changes.Transaction

  def notify(%Transaction{changes: changes}) when is_list(changes) do
    Logger.info(inspect(changes))
  end
end
