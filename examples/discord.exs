defmodule DiscordBot do
  use Fresh

  defstruct [:ready]

  @token System.get_env("BOT_TOKEN")

  def handle_connect(_status, _headers, _state) do
    {:ok, %__MODULE__{ready: false}}
  end

  def handle_in({:binary, frame}, state) do
    frame
    |> :erlang.binary_to_term()
    |> handle_websocket(state)
  end

  defp handle_websocket(%{op: 10}, state) do
    payload =
      :erlang.term_to_binary(%{
        "op" => 2,
        "d" => %{
          "token" => @token,
          "intents" => 33351,
          "properties" => %{
            "os" => "linux",
            "browser" => "fresh",
            "device" => "fresh"
          }
        }
      })

    {:reply, {:binary, payload}, %__MODULE__{state | ready: true}}
  end

  defp handle_websocket(
         %{t: :MESSAGE_CREATE, d: %{"author" => %{"global_name" => name}, "content" => content}},
         state
       ) do
    IO.puts("#{name}: #{content}")
    {:ok, state}
  end

  defp handle_websocket(_other, state) do
    {:ok, state}
  end
end

DiscordBot.start_link(uri: "wss://gateway.discord.gg/?v=10&encoding=etf", state: nil, opts: [])

Process.sleep(120_000)
