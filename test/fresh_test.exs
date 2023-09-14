defmodule FreshTest do
  use ExUnit.Case

  alias Fresh.TestServer
  alias Fresh.TestClient

  setup_all do
    TestServer.start(8080)
    :ok
  end

  describe "Connecting to:" do
    setup do
      [welcome: "hello", pid: self(), opts: [error_logging: false]]
    end

    test "Non-Existing Domain", state do
      TestClient.start(uri: "wss://none.bun.rip", state: state, opts: state[:opts])

      assert_receive {:error, {:connecting_failed, %Mint.TransportError{reason: :nxdomain}}}
    end

    test "Echo Server", state do
      TestClient.start_link(
        uri: "ws://localhost:8080/websocket",
        state: state,
        opts: state[:opts]
      )

      assert_receive {:data, {:text, "hello"}}
    end

    test "Echo Server with Registered Process", state do
      TestClient.start_link(
        uri: "ws://localhost:8080/websocket",
        state: state,
        opts: state[:opts] ++ [name: {:local, :client}]
      )

      assert_receive {:data, {:text, "hello"}}

      Fresh.send(:client, {:text, "hi :)"})
      assert_receive {:data, {:text, "hi :)"}}
    end
  end

  describe "Test Echo Server:" do
    setup do
      state = [welcome: "hi!", pid: self(), opts: [error_logging: false, ping_interval: 5_000]]

      {:ok, pid} =
        TestClient.start(
          uri: "ws://localhost:8080/websocket",
          state: state,
          opts: state[:opts]
        )

      receive do
        {:data, {:text, "hi!"}} ->
          [pid: pid]
      end
    end

    test "Send Text Frame", %{pid: pid} do
      Fresh.send(pid, {:text, "how are you?"})
      assert_receive {:data, {:text, "how are you?"}}
    end

    test "Send Binary Frame", %{pid: pid} do
      Fresh.send(pid, {:binary, <<13, 37>>})
      assert_receive {:data, {:binary, <<13, 37>>}}
    end

    test "Send Ping Frame", %{pid: pid} do
      Fresh.send(pid, {:ping, "wow"})
      assert_receive {:control, {:ping, "wow"}}
    end

    test "Send Pong Frame", %{pid: pid} do
      Fresh.send(pid, {:pong, "lol"})
      assert_receive {:control, {:pong, "lol"}}
    end

    test "Send Multiple Frame", %{pid: pid} do
      Fresh.send(pid, {:text, "ur"})
      Fresh.send(pid, {:binary, "cool"})
      Fresh.send(pid, {:ping, ":)"})

      assert_receive {:data, {:text, "ur"}}
      assert_receive {:data, {:binary, "cool"}}
      assert_receive {:control, {:ping, ":)"}}
    end

    test "Send Message to Process", %{pid: pid} do
      send(pid, {:send_frame, {:binary, <<1, 2, 3>>}})
      assert_receive {:data, {:binary, <<1, 2, 3>>}}

      send(pid, :another)
      assert_receive {:info, :another}
    end

    test "Close Connection with Close Frame", %{pid: pid} do
      Fresh.send(pid, {:close, 1002, ""})
      assert_receive {:close, 1000, ""}
    end

    test "Close Connection with Text Frame", %{pid: pid} do
      Fresh.send(pid, {:text, "close it!"})

      assert_receive {:close, 1013, "yessir"}
      assert_receive {:terminate, :shutdown}
    end

    test "Close Connection and Reconnect", %{pid: pid} do
      Fresh.send(pid, {:close, 1002, ""})

      assert_receive {:close, 1000, ""}
      assert_receive {:data, {:text, "hi!"}}

      Fresh.send(pid, {:binary, "hello once again!"})
      assert_receive {:data, {:binary, "hello once again!"}}
    end

    test "Wait for Ping", _ do
      assert_receive {:control, {:ping, ""}}, 10_000
    end
  end
end
