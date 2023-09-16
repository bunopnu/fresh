defmodule Fresh.TestServer do
  @moduledoc false

  def start(port) do
    children = [
      {Bandit, plug: Fresh.TestRouter, scheme: :http, port: port}
    ]

    opts = [strategy: :one_for_one, name: Fresh.TestServer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
