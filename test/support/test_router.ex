defmodule Fresh.TestRouter do
  use Plug.Router

  import Plug.Conn

  plug(:match)
  plug(:dispatch)

  get "/websocket" do
    header = get_req_header(conn, "client-test")

    conn
    |> WebSockAdapter.upgrade(Fresh.WebSocketHandler, %{header: header},
      timeout: :infinity,
      max_frame_size: 24
    )
    |> halt()
  end
end
