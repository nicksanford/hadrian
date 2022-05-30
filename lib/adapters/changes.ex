# This file draws heavily from https://github.com/cainophile/cainophile
# License: https://github.com/cainophile/cainophile/blob/master/LICENSE

defmodule Hadrian.Adapters.Changes do
  defmodule(Transaction, do: defstruct([:changes, :commit_timestamp]))

  defmodule(NewRecord,
    do: defstruct([:type, :record, :schema, :table, :columns, :commit_timestamp])
  )

  defmodule(UpdatedRecord,
    do: defstruct([:type, :old_record, :record, :schema, :table, :columns, :commit_timestamp])
  )

  defmodule(DeletedRecord,
    do: defstruct([:type, :old_record, :schema, :table, :columns, :commit_timestamp])
  )

  defmodule(TruncatedRelation, do: defstruct([:type, :schema, :table, :commit_timestamp]))
end
