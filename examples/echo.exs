defmodule EchoWebSocket do
  use Bousou

  def handle_connect(_status, headers, state) do
    IO.puts("Upgrade request headers: #{inspect(headers)}")
    {:reply, [{:text, state}], state}
  end

  def handle_frame({:text, state}, state) do
    IO.puts("Received state: #{state}")
    IO.puts("Start counting from 1:")

    {:reply, [{:text, "1"}], 0}
  end

  def handle_frame({:text, number}, _state) do
    number = String.to_integer(number)

    IO.puts("Number: #{number}")
    {:reply, [{:text, "#{number + 1}"}], number}
  end

  def handle_info(:stop, state) do
    IO.puts("Stopping at: #{state}")
    {:reply, [{:close, 1002, "example"}], state}
  end

  def handle_disconnect(_code, _reason, _state) do
    :close
  end
end

EchoWebSocket.start_link(uri: "wss://ws.postman-echo.com/raw", state: "hello!", opts: [
  name: {:local, Connection}
])

Process.sleep(10_000)

send(Connection, :stop)
