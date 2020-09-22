defmodule Logger.Backends.PhoenixPubSub.MixProject do
  use Mix.Project

  def project do
    [
      app: :phoenix_pubsub_logger,
      version: "1.0.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:phoenix_pubsub, "~> 2.0"},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:tracer, "~> 0.1.1", only: :dev}
    ]
  end
end
