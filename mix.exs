defmodule Fresh.MixProject do
  use Mix.Project

  @description "WebSocket client for Elixir, built atop the Mint ecosystem."
  @source_url "https://github.com/bunopnu/fresh"
  @version "0.1.0-rc"

  def project do
    [
      app: :fresh,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.github": :test,
        "coveralls.html": :test,
        docs: :dev
      ],

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

  defp elixirc_paths(:test), do: [~c"lib", ~c"test/support"]
  defp elixirc_paths(_), do: [~c"lib"]

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp deps do
    [
      {:mint, "~> 1.5"},
      {:mint_web_socket, "~> 1.0"},
      {:castore, "~> 1.0"},

      # Development
      {:ex_doc, "~> 0.30.6", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: :dev, runtime: false},

      # Testing
      {:plug, "~> 1.14", only: :test},
      {:bandit, "~> 0.7.7", only: :test},
      {:websock_adapter, "~> 0.5.4", only: :test},
      {:excoveralls, "~> 0.17.1", only: :test}
    ]
  end
end
