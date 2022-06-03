defmodule HadrianTest.Repo.Migrations.CreateHadrianPublication do
  use Ecto.Migration

  def up do
    execute("CREATE PUBLICATION hadrian FOR ALL TABLES")
  end

  def down do
    execute("DROP PUBLICATION hadrian")
  end
end
