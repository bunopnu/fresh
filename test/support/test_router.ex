defmodule Fresh.TestRouter do
  @moduledoc false

  use Plug.Router

  import Plug.Conn

  plug(:match)
  plug(:dispatch)

  get "/websocket" do
    conn
    |> WebSockAdapter.upgrade(Fresh.WebSocketHandler, [], timeout: :infinity)
    |> halt()
  end
end
