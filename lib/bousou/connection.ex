defmodule Bousou.Connection do
  @moduledoc false

  import Bousou.Log

  @behaviour :gen_statem

  defstruct [
    :module,
    :default_state,
    :inner_state,
    :uri,
    :opts,
    :connection,
    :error,
    :reconnect,
    :websocket,
    :request_ref,
    :response_status,
    :response_headers
  ]

  ### ===============================================================
  ###
  ###  State machine
  ###
  ### ===============================================================

  @impl true
  def callback_mode() do
    :state_functions
  end

  @impl true
  def init({uri, state, opts, module}) do
    data = %__MODULE__{
      uri: uri,
      opts: opts,
      module: module,
      default_state: state,
      inner_state: state
    }

    actions = [{:next_event, :internal, :connect}]
    {:ok, :disconnected, data, actions}
  end

  def disconnected(:internal, :connect, data) do
    uri = URI.parse(data.uri)

    {http_scheme, ws_scheme} =
      case uri.scheme do
        "ws" -> {:http, :ws}
        "wss" -> {:https, :wss}
      end

    path =
      case uri.query do
        nil -> uri.path
        query -> uri.path <> "?" <> query
      end

    headers = Keyword.get(data.opts, :headers, [])

    connect_opts = [
      protocols: [:http1],
      transport_opts: Keyword.get(data.opts, :transport_opts, [])
    ]

    upgrade_opts = Keyword.get(data.opts, :mint_upgrade_opts, [])

    with {:ok, conn} <- Mint.HTTP.connect(http_scheme, uri.host, uri.port, connect_opts),
         {:ok, conn, ref} <- Mint.WebSocket.upgrade(ws_scheme, conn, path, headers, upgrade_opts) do
      {:next_state, :connected, %__MODULE__{data | connection: conn, request_ref: ref}}
    else
      {:error, reason} ->
        log(:error, :connecting_failed, reason)
        reconnect(data)

      {:error, conn, reason} ->
        log(:error, :upgrading_failed, reason)
        reconnect(%__MODULE__{data | connection: conn})
    end
  end

  def disconnected(:cast, {:request, _frame}, _data) do
    :keep_state_and_data
  end

  def connected(:info, message, data) do
    case Mint.WebSocket.stream(data.connection, message) do
      {:ok, conn, responses} ->
        data = Enum.reduce(responses, %__MODULE__{data | connection: conn}, &handle_response/2)

        cond do
          data.error == true or data.reconnect == true ->
            reconnect(data)

          data.reconnect == false ->
            {:stop, :normal}

          true ->
            {:keep_state, data}
        end

      {:error, conn, reason, _responses} ->
        log(:error, :streaming_failed, reason)
        reconnect(%__MODULE__{data | connection: conn})

      :unknown ->
        data =
          message
          |> data.module.handle_info(data.inner_state)
          |> handle_callback(data)

        {:keep_state, data}
    end
  end

  def connected(:cast, {:request, frame}, data) do
    send_frame(frame, data)
  end

  ### ===============================================================
  ###
  ###  Response handler
  ###
  ### ===============================================================

  defp handle_response({:status, _ref, status}, data) do
    %__MODULE__{data | response_status: status}
  end

  defp handle_response({:headers, _ref, headers}, data) do
    %__MODULE__{data | response_headers: headers}
  end

  defp handle_response({:done, ref}, data) do
    case Mint.WebSocket.new(data.connection, ref, data.response_status, data.response_headers) do
      {:ok, conn, websocket} ->
        log(:info, :established, nil)

        data = %__MODULE__{data | connection: conn, websocket: websocket}

        data.response_status
        |> data.module.handle_connect(data.response_headers, data.inner_state)
        |> handle_callback(data)

      {:error, conn, reason} ->
        log(:error, :establishing_failed, reason)
        %__MODULE__{data | connection: conn, error: true}
    end
  end

  defp handle_response({:data, _ref, message}, data) do
    case Mint.WebSocket.decode(data.websocket, message) do
      {:ok, websocket, frames} ->
        Enum.reduce(frames, %__MODULE__{data | websocket: websocket}, &handle_frame/2)

      {:error, websocket, reason} ->
        log(:error, :decoding_failed, reason)
        %__MODULE__{data | websocket: websocket, error: true}
    end
  end

  ### ===============================================================
  ###
  ###  Frame handler
  ###
  ### ===============================================================

  defp send_frame(frame, data) do
    with {:ok, websocket, frame_data} <- Mint.WebSocket.encode(data.websocket, frame),
         data = %__MODULE__{data | websocket: websocket},
         {:ok, conn} <-
           Mint.WebSocket.stream_request_body(data.connection, data.request_ref, frame_data) do
      {:keep_state, %__MODULE__{data | connection: conn}}
    else
      {:error, websocket, reason} when is_struct(websocket, Mint.WebSocket) ->
        log(:error, :sending_failed, reason)
        {:keep_state, %__MODULE__{data | websocket: websocket}}

      {:error, conn, reason} ->
        log(:error, :sending_failed, reason)
        {:keep_state, %__MODULE__{data | connection: conn}}
    end
  end

  defp handle_frame({:ping, message}, data) do
    {:keep_state, data} = send_frame({:pong, message}, data)

    if Keyword.get(data.opts, :silence_pings, true) do
      data
    else
      message
      |> data.module.handle_ping(data.inner_state)
      |> handle_callback(data)
    end
  end

  defp handle_frame({:close, code, reason}, data) do
    log(:error, :dropping, {code, reason})

    case data.module.handle_disconnect(code, reason, data.inner_state) do
      {:reconnect, inner_state} ->
        %__MODULE__{data | default_state: inner_state, reconnect: true}

      :reconnect ->
        %__MODULE__{data | reconnect: true}

      :close ->
        %__MODULE__{data | reconnect: false}
    end
  end

  defp handle_frame(frame, data) do
    frame
    |> data.module.handle_frame(data.inner_state)
    |> handle_callback(data)
  end

  ### ===============================================================
  ###
  ###  Callback response handler
  ###
  ### ===============================================================

  defp handle_callback({:ok, inner_state}, data) do
    %__MODULE__{data | inner_state: inner_state}
  end

  defp handle_callback({:reply, frames, inner_state}, data) when is_list(frames) do
    data =
      Enum.reduce(frames, data, fn frame, acc ->
        {:keep_state, new_acc} = send_frame(frame, acc)
        new_acc
      end)

    %__MODULE__{data | inner_state: inner_state}
  end

  ### ===============================================================
  ###
  ###  Clean reconnect
  ###
  ### ===============================================================

  defp reconnect(data) do
    if data.connection do
      Mint.HTTP.close(data.connection)
    end

    data = %__MODULE__{
      uri: data.uri,
      opts: data.opts,
      module: data.module,
      default_state: data.default_state,
      inner_state: data.default_state
    }

    actions = [{:next_event, :internal, :connect}]
    {:next_state, :disconnected, data, actions}
  end
end
