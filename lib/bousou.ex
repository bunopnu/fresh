defmodule Bousou do
  @moduledoc "Bousou (暴走) is a WebSocket client for Elixir."

  alias Bousou.Spawn

  @type frame :: Mint.WebSocket.frame()
  @type headers :: Mint.Types.headers()
  @type state :: any()
  @type status :: Mint.Types.status()

  @type opts ::
          {:name, :gen_statem.server_name()}
          | {:headers, Mint.Types.headers()}
          | {:silence_pings, boolean()}

  @type disconnect_code :: non_neg_integer() | nil
  @type disconnect_reason :: binary() | nil

  @type generic_handle_res :: {:ok, state()} | {:reply, list(frame()), state()}
  @type disconnect_res :: {:reconnect, state()} | :reconnect | :close

  @doc "Invoked after connection is established."
  @callback handle_connect(status(), headers(), state()) :: generic_handle_res()

  @doc "Invoked when receive ping frame from connection."
  @callback handle_ping(binary(), state()) :: generic_handle_res()

  @doc "Invoked when receive frame from connection."
  @callback handle_frame(frame(), state()) :: generic_handle_res()

  @doc "Invoked to handle unknown messages."
  @callback handle_info(any(), state()) :: generic_handle_res()

  @doc "Invoked while connection is closing."
  @callback handle_disconnect(disconnect_code(), disconnect_reason(), state()) :: disconnect_res()

  @spec start_link(binary(), module(), any(), list(opts())) :: :gen_statem.start_ret()
  def start_link(uri, module, state, opts) do
    Spawn.start(:start_link, uri, module, state, opts)
  end

  @spec start(binary(), module(), any(), list(opts())) :: :gen_statem.start_ret()
  def start(uri, module, state, opts) do
    Spawn.start(:start, uri, module, state, opts)
  end

  @spec send(:gen_statem.server_ref(), Mint.WebSocket.frame()) :: :ok
  def send(pid, frame) do
    :gen_statem.cast(pid, {:request, frame})
  end
end
