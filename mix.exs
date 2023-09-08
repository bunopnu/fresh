defmodule Bousou.MixProject do
  use Mix.Project

  def project do
    [
      app: :bousou,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # documentation
      name: "Bousou",
      source_url: "https://github.com/bunopnu/bousou",
      docs: [
        main: "readme",
        extras: ["README.md"]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:mint, "~> 1.5"},
      {:mint_web_socket, "~> 1.0"},
      {:castore, "~> 1.0"},
      {:ex_doc, "~> 0.30.6", only: :dev, runtime: false}
    ]
  end
end
