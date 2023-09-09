defmodule Fresh.MixProject do
  use Mix.Project

  @description "WebSocket client for Elixir, built atop the Mint ecosystem."
  @source_url "https://github.com/bunopnu/fresh"
  @version "0.1.0"

  def project do
    [
      app: :fresh,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Package
      package: package(),
      description: @description,

      # Documentation
      name: "Fresh",
      source_url: @source_url,
      docs: [
        main: "readme",
        extras: [
          "README.md": [title: "Introduction"],
          LICENSE: [title: "License"]
        ]
      ],

      # Dialyzer
      dialyzer: [
        plt_local_path: "priv/plts",
        plt_core_path: "priv/plts"
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package do
    [
      licenses: ["MIT License"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp deps do
    [
      {:mint, "~> 1.5"},
      {:mint_web_socket, "~> 1.0"},
      {:castore, "~> 1.0"},

      # Development
      {:ex_doc, "~> 0.30.6", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: :dev, runtime: false}
    ]
  end
end
