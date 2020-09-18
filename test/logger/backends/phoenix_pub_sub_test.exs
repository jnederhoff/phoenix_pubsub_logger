defmodule Logger.Backends.PhoenixPubSubTest do
  use ExUnit.Case
  require Logger
  doctest Logger.Backends.PhoenixPubSub

  setup_all _context do
    {:ok, _pid} = start_supervised({Phoenix.PubSub, name: TestPubSub})

    {:ok, backend_pid} = Logger.add_backend(Logger.Backends.PhoenixPubSub)

    :ok =
      Logger.configure_backend(
        Logger.Backends.PhoenixPubSub,
        pubsub: TestPubSub,
        topic: "logger"
      )

    :ok = Logger.remove_backend(:console)

    {:ok, backend_pid: backend_pid}
  end

  setup _context do
    :ok = Phoenix.PubSub.subscribe(TestPubSub, "logger")

    on_exit(fn ->
      :ok = Phoenix.PubSub.unsubscribe(TestPubSub, "logger")

      :ok =
        Logger.configure_backend(
          Logger.Backends.PhoenixPubSub,
          format: nil,
          level: nil,
          metadata: [],
          pubsub: TestPubSub,
          topic: "logger"
        )
    end)

    :ok
  end

  test "pubsub sanity check" do
    Phoenix.PubSub.broadcast(TestPubSub, "logger", {:log_message, "test"})

    assert_received {:log_message, "test"}
  end

  test "configures format" do
    Logger.configure_backend(Logger.Backends.PhoenixPubSub, format: "$message [$level]")

    assert capture_log(fn -> Logger.debug("hello") end) =~ "hello [debug]"
  end

  test "configures metadata" do
    Logger.configure_backend(Logger.Backends.PhoenixPubSub,
      format: "$metadata$message",
      metadata: [:user_id]
    )

    assert capture_log(fn -> Logger.debug("hello") end) =~ "hello"

    Logger.metadata(user_id: 11)
    Logger.metadata(user_id: 13)
    assert capture_log(fn -> Logger.debug("hello") end) =~ "user_id=13 hello"
  end

  test "logs initial_call as metadata" do
    Logger.configure_backend(Logger.Backends.PhoenixPubSub,
      format: "$metadata$message",
      metadata: [:initial_call]
    )

    assert capture_log(fn -> Logger.debug("hello", initial_call: {Foo, :bar, 3}) end) =~
             "initial_call=Foo.bar/3 hello"
  end

  test "logs domain as metadata" do
    Logger.configure_backend(Logger.Backends.PhoenixPubSub,
      format: "$metadata$message",
      metadata: [:domain]
    )

    assert capture_log(fn -> Logger.debug("hello", domain: [:foobar]) end) =~
             "domain=elixir.foobar hello"
  end

  test "logs mfa as metadata" do
    Logger.configure_backend(Logger.Backends.PhoenixPubSub,
      format: "$metadata$message",
      metadata: [:mfa]
    )

    {function, arity} = __ENV__.function
    mfa = Exception.format_mfa(__MODULE__, function, arity)

    assert capture_log(fn -> Logger.debug("hello") end) =~
             "mfa=#{mfa} hello"
  end

  test "ignores crash_reason metadata when configured with metadata: :all" do
    Logger.configure_backend(Logger.Backends.PhoenixPubSub,
      format: "$metadata$message",
      metadata: :all
    )

    Logger.metadata(crash_reason: {%RuntimeError{message: "oops"}, []})
    assert capture_log(fn -> Logger.debug("hello") end) =~ "hello"
  end

  test "configures formatter to {module, function} tuple" do
    Logger.configure_backend(Logger.Backends.PhoenixPubSub, format: {__MODULE__, :format})

    assert capture_log(fn -> Logger.debug("hello") end) =~ "my_format: hello"
  end

  def format(_level, message, _ts, _metadata) do
    "my_format: #{message}"
  end

  test "configures metadata to :all" do
    Logger.configure_backend(Logger.Backends.PhoenixPubSub, format: "$metadata", metadata: :all)
    Logger.metadata(user_id: 11)
    Logger.metadata(dynamic_metadata: 5)

    %{module: mod, function: {name, arity}, file: file, line: line} = __ENV__
    log = capture_log(fn -> Logger.debug("hello") end)

    assert log =~ "file=#{file}"
    assert log =~ "line=#{line + 1}"
    assert log =~ "module=#{inspect(mod)}"
    assert log =~ "function=#{name}/#{arity}"
    assert log =~ "dynamic_metadata=5"
    assert log =~ "user_id=11"
  end

  test "provides metadata defaults" do
    metadata = [:file, :line, :module, :function]

    Logger.configure_backend(Logger.Backends.PhoenixPubSub,
      format: "$metadata",
      metadata: metadata
    )

    %{module: mod, function: {name, arity}, file: file, line: line} = __ENV__
    log = capture_log(fn -> Logger.debug("hello") end)

    assert log =~ "file=#{file} line=#{line + 1} module=#{inspect(mod)} function=#{name}/#{arity}"
  end

  test "configures level" do
    Logger.configure_backend(Logger.Backends.PhoenixPubSub, level: :info)

    Logger.debug("hello")

    refute_receive {:log_message, _message}
  end

  test "PubSub backend failure does not cause crash", context do
    Logger.configure_backend(Logger.Backends.PhoenixPubSub, pubsub: MissingPubSub)

    Logger.debug("hello")

    assert Process.alive?(context.backend_pid)
  end

  test "multiple instances of backend are allowed" do
    :ok = Phoenix.PubSub.unsubscribe(TestPubSub, "logger")

    {:ok, _pid} = Logger.add_backend({Logger.Backends.PhoenixPubSub, :number_two})

    :ok =
      Logger.configure_backend(
        {Logger.Backends.PhoenixPubSub, :number_two},
        pubsub: TestPubSub,
        topic: "number_two",
        format: "$message"
      )

    :ok = Phoenix.PubSub.subscribe(TestPubSub, "number_two")

    Logger.debug("hello")

    assert_receive {:log_message, _message}
  end

  def capture_log(level \\ :debug, fun) do
    Logger.configure(level: level)

    fun.()

    receive do
      {:log_message, value} ->
        IO.chardata_to_string(value)
    end
  after
    Logger.configure(level: :debug)
  end
end
