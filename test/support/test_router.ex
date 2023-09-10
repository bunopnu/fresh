defmodule Fresh.TestRouter do
  use Plug.Router

  import Plug.Conn

  plug(:match)
  plug(:dispatch)

  get "/websocket" do
    conn
    |> WebSockAdapter.upgrade(Fresh.WebSocketHandler, [], timeout: :infinity, max_frame_size: 24)
    |> halt()
  end
end
