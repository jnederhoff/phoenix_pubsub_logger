# Logger.Backends.PhoenixPubSub

Provides a Logger backend that will publish log messages to the Phoenix Pubsub process and topic of your choice.  It accepts format strings in the same manner as the default :console backend.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `phoenix_pubsub_logger` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:phoenix_pubsub_logger, "~> 1.0.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/phoenix_pubsub_logger](https://hexdocs.pm/phoenix_pubsub_logger).

