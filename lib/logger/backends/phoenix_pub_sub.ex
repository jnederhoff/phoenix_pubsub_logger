defmodule Logger.Backends.PhoenixPubSub do
  @moduledoc """
  Documentation for `Logger.Backends.PhoenixPubSub`.
  """
  @behaviour :gen_event

  defstruct name: nil,
            format: nil,
            level: nil,
            metadata: nil,
            pubsub: nil,
            topic: nil

  @impl :gen_event
  def init(__MODULE__) do
    init({__MODULE__, :phoenix_pubsub_logger})
  end

  def init({__MODULE__, name}) when is_atom(name) do
    {:ok, configure([], %__MODULE__{name: name})}
  end

  @impl :gen_event
  def handle_call({:configure, options}, state) do
    {:ok, :ok, configure(options, state)}
  end

  @impl :gen_event
  def handle_event({level, _gl, {Logger, msg, ts, md}}, state) do
    %{level: log_level} = state

    cond do
      meet_level?(level, log_level) ->
        {:ok, log_event(level, msg, ts, md, state)}

      true ->
        {:ok, state}
    end
  end

  def handle_event(_, state) do
    {:ok, state}
  end

  @impl :gen_event
  def handle_info(_, state) do
    {:ok, state}
  end

  @impl :gen_event
  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

  @impl :gen_event
  def terminate(_reason, _state) do
    :ok
  end

  ## Helpers

  defp meet_level?(_lvl, nil), do: true

  defp meet_level?(lvl, min) do
    Logger.compare_levels(lvl, min) != :lt
  end

  defp configure(options, state) do
    config = Keyword.merge(Application.get_env(:logger, state.name, []), options)
    Application.put_env(:logger, state.name, config)
    init_state(config, state)
  end

  defp init_state(config, state) do
    format = Logger.Formatter.compile(Keyword.get(config, :format))
    level = Keyword.get(config, :level)
    metadata = Keyword.get(config, :metadata, []) |> configure_metadata()
    pubsub = Keyword.get(config, :pubsub)
    topic = Keyword.get(config, :topic)

    %{
      state
      | format: format,
        level: level,
        metadata: metadata,
        pubsub: pubsub,
        topic: topic
    }
  end

  defp configure_metadata(:all), do: :all
  defp configure_metadata(metadata), do: Enum.reverse(metadata)

  defp log_event(_level, _msg, _ts, _md, %__MODULE__{pubsub: nil}) do
    raise PhoenixPubSubLoggerException, message: "pubsub not configured"
  end

  defp log_event(_level, _msg, _ts, _md, %__MODULE__{topic: nil}) do
    raise PhoenixPubSubLoggerException, message: "topic not configured"
  end

  defp log_event(level, msg, ts, md, %__MODULE__{pubsub: pubsub, topic: topic} = state) do
    message = format_event(level, msg, ts, md, state)

    Phoenix.PubSub.broadcast!(pubsub, topic, {:log_message, message})

    state
  rescue
    _ ->
      state
  end

  defp format_event(_level, _msg, _ts, _md, %__MODULE__{format: nil}) do
    raise PhoenixPubSubLoggerException, message: "format not configured"
  end

  defp format_event(level, msg, ts, md, state) do
    %{format: format, metadata: keys} = state

    Logger.Formatter.format(format, level, msg, ts, take_metadata(md, keys))
  end

  defp take_metadata(metadata, :all) do
    metadata
  end

  defp take_metadata(metadata, keys) do
    Enum.reduce(keys, [], fn key, acc ->
      case Keyword.fetch(metadata, key) do
        {:ok, val} -> [{key, val} | acc]
        :error -> acc
      end
    end)
  end
end

defmodule PhoenixPubSubLoggerException do
  defexception message: "exception in phoenix_pubsub_logger"
end
