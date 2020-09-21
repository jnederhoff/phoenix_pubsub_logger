ExUnit.configure(exclude: [:exclude])
ExUnit.start()

defmodule Logger.Case do
  use ExUnit.CaseTemplate

  using _ do
    quote do
      import Logger.Case
    end
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

  def ex_vsn(target, opts \\ []) do
    if Version.match?(System.version(), target, opts), do: :exclude
  end
end
