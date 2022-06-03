import Config

config :hadrian, HadrianTest.Repo,
  database: System.get_env("DATABASE"),
  username: System.get_env("USERNAME"),
  hostname: System.get_env("HOSTNAME")
