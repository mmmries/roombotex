defmodule Roombotex.Mixfile do
  use Mix.Project

  def project do
    [
      app: :roombotex,
      version: "0.0.1",
      elixir: "~> 1.1",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps,
      aliases: aliases,
    ]
  end

  def application do
    [applications: [:logger, :crypto, :ssl]]
  end

  defp aliases do
    [
      c: "compile",
      shy: ["compile", &shy/1],
    ]
  end

  defp deps do
    [
      {:websocket_client, "~> 1.1.0"},
      {:poison, "~> 1.5"},
    ]
  end

  defp sleep do
    :timer.sleep(5_000)
    sleep
  end

  defp shy([url]) do
    url = :erlang.binary_to_list(url)
    ShyGuy.start_link(url: url)
    sleep
  end
end
