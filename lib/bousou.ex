defmodule Bousou do
  @moduledoc "Bousou (暴走) is a WebSocket client for Elixir."

  @type frame :: Mint.WebSocket.frame()
  @type headers :: Mint.Types.headers()
  @type state :: any()
  @type status :: Mint.Types.status()

  @type disconnect_code :: non_neg_integer() | nil
  @type disconnect_reason :: binary() | nil

  @type generic_handle_res :: {:ok, state()} | {:reply, list(frame()), state()}
  @type disconnect_res :: {:reconnect, state()} | :reconnect | :close

  @doc "Invoked after connection is established."
  @callback handle_connect(status(), headers(), state()) :: generic_handle_res()

  @doc "Invoked when receive new frame from connection."
  @callback handle_frame(frame(), state()) :: generic_handle_res()

  @doc "Invoked to handle unknown messages."
  @callback handle_info(any(), state()) :: generic_handle_res()

  @doc "Invoked while connection is closing."
  @callback handle_disconnect(disconnect_code(), disconnect_reason(), state()) :: disconnect_res()

  @type conn_opts :: {:headers, Mint.Types.headers()}
  @type opts :: {:name, module()} | {:uri, binary()} | {:init, any()} | {:opts, list(conn_opts)}

  @spec start_link(atom(), list(opts())) :: :gen_statem.start_ret()
  def start_link(module, opts) do
    conn_name = Keyword.fetch!(opts, :name)
    conn_uri = Keyword.fetch!(opts, :uri)
    conn_state = Keyword.fetch!(opts, :init)
    conn_opts = Keyword.get(opts, :opts, [])

    initial = {conn_uri, conn_state, conn_opts, module}

    :gen_statem.start_link({:local, conn_name}, Bousou.Connection, initial, [])
  end

  @spec send(:gen_statem.server_ref(), Mint.WebSocket.frame()) :: :ok
  def send(pid, frame) do
    :gen_statem.cast(pid, {:request, frame})
  end
end
