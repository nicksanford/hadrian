defmodule HadrianTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  @required_keys [
    :notify_callback,
    :host,
    :username,
    :database,
    :port,
    :ssl,
    :password,
    :ip_version,
    :publications,
    :slot_name,
    :wal_position,
    :max_replication_lag_in_mb
  ]
  @string_vals [:host, :username, :database, :password]
  @string_list_vals [:publications]
  @boolean_vals [:ssl]
  @non_neg_int_vals [:max_replication_lag_in_mb, :port]

  setup do
    valid_config = [
      notify_callback: fn _ -> :ok end,
      host: "localhost",
      username: "some_username",
      database: "some_database",
      port: 3888,
      ssl: true,
      password: "some_password",
      ip_version: :ipv4,
      publications: ["a_publication"],
      slot_name: "a_slot_name",
      wal_position: {"0", "0"},
      max_replication_lag_in_mb: 0
    ]

    %{valid_config: valid_config}
  end

  describe "integraton tests" do
    test "crashes if db doesn't exist", %{valid_config: valid_config} do
      logs =
        capture_log([level: :error], fn ->
          pid = start_supervised!({Hadrian, valid_config}, restart: :temporary)
          :timer.sleep(200)
          refute Process.alive?(pid)
        end)

      assert logs =~ "[error] GenServer "
      assert logs =~ "terminating"
      assert logs =~ "** (stop) :econnrefused"
    end

    @tag skip: true
    test "calls notify_callback with create, update and delete messages", %{
      valid_config: valid_config
    } do
      start_supervised!({Hadrian, valid_config})
    end

    @tag skip: true
    test "if notify_callback fails...", %{valid_config: valid_config} do
      start_supervised!({Hadrian, valid_config})
    end

    @tag skip: true
    test "if replecation process dies...", %{valid_config: valid_config} do
      start_supervised!({Hadrian, valid_config})
    end

    @tag skip: true
    test "if epgsql_server process dies...", %{valid_config: valid_config} do
      start_supervised!({Hadrian, valid_config})
    end

    @tag skip: true
    test "if not provided a slot, starts temp mode", %{valid_config: valid_config} do
      start_supervised!({Hadrian, valid_config})
    end

    @tag skip: true
    test "if the replication lag exceeds the set limit", %{valid_config: valid_config} do
      start_supervised!({Hadrian, valid_config})
    end

    @tag skip: true
    test "if the publication is dropped", %{valid_config: valid_config} do
      start_supervised!({Hadrian, valid_config})
    end

    @tag skip: true
    test "if the requested WAL segment has already been removed", %{valid_config: valid_config} do
      start_supervised!({Hadrian, valid_config})
    end

    @tag skip: true
    test "is able to run multiple instances", %{valid_config: valid_config} do
      start_supervised!({Hadrian, valid_config})
    end
  end

  describe "start_link/1 validations" do
    test "raises if not provided config" do
      assert_raise RuntimeError,
                   ~r/\(ArgumentError\) the following keys must also be given when building struct Hadrian.Config: /,
                   fn ->
                     start_supervised!({Hadrian, []})
                   end
    end

    test "raises if provided invalid config" do
      assert_raise RuntimeError,
                   ~r/\(ArgumentError\) unknown option pair provided {:invalid, :config}/,
                   fn ->
                     start_supervised!({Hadrian, [invalid: :config]})
                   end
    end

    test "raises if :ip_version is anything other than :ipv4 or :ipv6", %{
      valid_config: valid_config
    } do
      assert_raise RuntimeError,
                   ~r/\(ArgumentError\) expected ip_version to be either :ipv4 or :ipv6, instead got :notipv4orv6\n/,
                   fn ->
                     start_supervised!(
                       {Hadrian, Keyword.merge(valid_config, ip_version: :notipv4orv6)}
                     )
                   end
    end

    test "raises if :notify_callback is anything other than a single arity function", %{
      valid_config: valid_config
    } do
      assert_raise RuntimeError,
                   ~r/\(ArgumentError\) expected notify_callback to be a single arity function, instead got #Function/,
                   fn ->
                     start_supervised!(
                       {Hadrian, Keyword.merge(valid_config, notify_callback: fn _, _ -> :ok end)}
                     )
                   end
    end

    test "raises if :wal_position is anything other than a 2 tuple containing strings", %{
      valid_config: valid_config
    } do
      assert_raise RuntimeError,
                   ~r/\(ArgumentError\) expected wal_position to be a 2 tuple containing hex strings which represent the pg_lsn type.\nE.g. {\"0\", \"0\"}/,
                   fn ->
                     start_supervised!(
                       {Hadrian, Keyword.merge(valid_config, wal_position: {0, 0})}
                     )
                   end
    end

    test "raises if :slot_name is anything other than a non empty string", %{
      valid_config: valid_config
    } do
      assert_raise RuntimeError,
                   ~r/\(ArgumentError\) expected slot_name to be a non empty string, instead got \"\"\n/,
                   fn ->
                     start_supervised!({Hadrian, Keyword.merge(valid_config, slot_name: "")})
                   end

      assert_raise RuntimeError,
                   ~r/\(ArgumentError\) expected slot_name to be a non empty string, instead got 0\n/,
                   fn ->
                     start_supervised!({Hadrian, Keyword.merge(valid_config, slot_name: 0)})
                   end
    end

    test "raises if string vals are non strings", %{
      valid_config: valid_config
    } do
      for required_key <- @string_vals do
        assert_raise RuntimeError,
                     ~r/\(ArgumentError\) expected #{required_key} to be a string, instead got 0\n/,
                     fn ->
                       start_supervised!(
                         {Hadrian, Keyword.merge(valid_config, [{required_key, 0}])}
                       )
                     end
      end
    end

    test "raises if string list vals are not lists of strings", %{
      valid_config: valid_config
    } do
      for required_key <- @string_list_vals do
        assert_raise RuntimeError,
                     ~r/\(ArgumentError\) expected #{required_key} to be a non empty list of strings, instead got 0\n/,
                     fn ->
                       start_supervised!(
                         {Hadrian, Keyword.merge(valid_config, [{required_key, 0}])}
                       )
                     end

        assert_raise RuntimeError,
                     ~r/\(ArgumentError\) expected #{required_key} to be a non empty list of strings, instead got \[\]\n/,
                     fn ->
                       start_supervised!(
                         {Hadrian, Keyword.merge(valid_config, [{required_key, []}])}
                       )
                     end

        assert_raise RuntimeError,
                     ~r/\(ArgumentError\) expected #{required_key} to be a non empty list of strings, instead got \[\"a\", 1\]\n/,
                     fn ->
                       start_supervised!(
                         {Hadrian, Keyword.merge(valid_config, [{required_key, ["a", 1]}])}
                       )
                     end
      end
    end

    test "raises if bool vals are not bools", %{
      valid_config: valid_config
    } do
      for required_key <- @boolean_vals do
        assert_raise RuntimeError,
                     ~r/\(ArgumentError\) expected #{required_key} to be a boolean, instead got 0\n/,
                     fn ->
                       start_supervised!(
                         {Hadrian, Keyword.merge(valid_config, [{required_key, 0}])}
                       )
                     end
      end
    end

    test "raises if non neg int vals are not non negative ints", %{
      valid_config: valid_config
    } do
      for required_key <- @non_neg_int_vals do
        assert_raise RuntimeError,
                     ~r/\(ArgumentError\) expected #{required_key} to be a non negative integer, instead got -1\n/,
                     fn ->
                       start_supervised!(
                         {Hadrian, Keyword.merge(valid_config, [{required_key, -1}])}
                       )
                     end
      end
    end

    test "raises if a required key is not provided", %{valid_config: valid_config} do
      for required_key <- @required_keys do
        assert_raise(
          RuntimeError,
          ~r/\(ArgumentError\) the following keys must also be given when building struct Hadrian.Config:/,
          fn ->
            start_supervised!({Hadrian, Keyword.delete(valid_config, required_key)})
          end
        )
      end
    end
  end
end
