defmodule HadrianTest.Repo do
  use Ecto.Repo,
    otp_app: :hadrian,
    adapter: Ecto.Adapters.Postgres
end
