defmodule Fresh.Connection do
  @moduledoc false

  alias Fresh.Option

  import Fresh.Log

  @behaviour :gen_statem

  defstruct [
    :module,
    :default_state,
    :inner_state,
    :uri,
    :opts,
    :connection,
    :reconnect,
    :websocket,
    :request_ref,
    :response_status,
    :response_headers,
    :response_queue,
    :backoff_time
  ]

  ### ===============================================================
  ###
  ###  State machine
  ###
  ### ===============================================================

  @impl true
  def callback_mode do
    :state_functions
  end

  @impl true
  def init({uri, state, opts, module}) do
    data = %__MODULE__{
      uri: uri,
      opts: opts,
      module: module,
      default_state: state,
      inner_state: state,
      response_queue: [],
      backoff_time: Option.backoff_initial(opts)
    }

    ping_interval = Option.ping_interval(opts)

    if ping_interval != 0 do
      :timer.send_interval(ping_interval, :ping)
    end

    actions = [{:next_event, :internal, :connect}]
    {:ok, :disconnected, data, actions}
  end

  def disconnected(:info, :reconnect, _data) do
    {:keep_state_and_data, {:next_event, :internal, :connect}}
  end

  def disconnected(:info, _message, _data) do
    :keep_state_and_data
  end

  def disconnected(:internal, :connect, data) do
    uri = URI.parse(data.uri)

    {http_scheme, ws_scheme} =
      case uri.scheme do
        "ws" -> {:http, :ws}
        "wss" -> {:https, :wss}
      end

    path = uri.path || "/"

    path =
      case uri.query do
        nil -> path
        query -> path <> "?" <> query
      end

    headers = Option.headers(data.opts)

    connect_opts = [
      protocols: [:http1],
      transport_opts: Option.transport_opts(data.opts)
    ]

    upgrade_opts = Option.mint_upgrade_opts(data.opts)

    with {:ok, conn} <- Mint.HTTP.connect(http_scheme, uri.host, uri.port, connect_opts),
         {:ok, conn, ref} <- Mint.WebSocket.upgrade(ws_scheme, conn, path, headers, upgrade_opts) do
      {:next_state, :connected, %__MODULE__{data | connection: conn, request_ref: ref}}
    else
      {:error, reason} ->
        {:connecting_failed, reason}
        |> handle_error(data)
        |> data_to_event()

      {:error, conn, reason} ->
        {:upgrading_failed, reason}
        |> handle_error(data, connection: conn)
        |> data_to_event()
    end
  end

  def disconnected(:cast, {:request, _frame}, _data) do
    :keep_state_and_data
  end

  def disconnected({:call, from}, :available, _data) do
    :gen_statem.reply(from, false)
    :keep_state_and_data
  end

  def connected(:info, :ping, data) do
    {:ping, <<>>}
    |> send_frame(data)
    |> data_to_event()
  end

  def connected(:info, message, data) do
    case Mint.WebSocket.stream(data.connection, message) do
      {:ok, conn, responses} ->
        responses
        |> Enum.reduce(%__MODULE__{data | connection: conn}, &handle_response/2)
        |> data_to_event()

      {:error, conn, reason, _responses} ->
        {:streaming_failed, reason}
        |> handle_error(data, connection: conn)
        |> data_to_event()

      :unknown ->
        message
        |> data.module.handle_info(data.inner_state)
        |> handle_generic_callback(data)
        |> data_to_event()
    end
  end

  def connected(:cast, {:request, frame}, data) do
    frame
    |> send_frame(data)
    |> data_to_event()
  end

  def connected({:call, from}, :available, %__MODULE__{connection: connection}) do
    :gen_statem.reply(from, Mint.HTTP.open?(connection))
    :keep_state_and_data
  end

  @impl true
  def terminate(reason, _state, data) do
    data.module.handle_terminate(reason, data.inner_state)
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
        log(:info, :established, nil, data.opts)

        data = %__MODULE__{data | connection: conn, websocket: websocket}

        data.response_status
        |> data.module.handle_connect(data.response_headers, data.inner_state)
        |> handle_generic_callback(data)
        |> handle_response_queue()
        |> struct(backoff_time: Option.backoff_initial(data.opts))

      {:error, conn, reason} ->
        handle_error({:establishing_failed, reason}, data, connection: conn)
    end
  end

  defp handle_response({:error, _ref, reason}, data) do
    handle_error({:processing_failed, reason}, data)
  end

  defp handle_response({:data, _ref, message}, data) do
    if data.websocket != nil do
      case Mint.WebSocket.decode(data.websocket, message) do
        {:ok, websocket, frames} ->
          Enum.reduce(frames, %__MODULE__{data | websocket: websocket}, &handle_frame/2)

        {:error, websocket, reason} ->
          handle_error({:decoding_failed, reason}, data, websocket: websocket)
      end
    else
      %__MODULE__{data | response_queue: [message | data.response_queue]}
    end
  end

  ### ===============================================================
  ###
  ###  Frame handler
  ###
  ### ===============================================================

  defp send_frame(frames, data) when is_list(frames) do
    Enum.reduce(frames, data, &send_frame/2)
  end

  defp send_frame(frame, data) do
    with {:ok, websocket, frame_data} <- Mint.WebSocket.encode(data.websocket, frame),
         data = %__MODULE__{data | websocket: websocket},
         {:ok, conn} <-
           Mint.WebSocket.stream_request_body(data.connection, data.request_ref, frame_data) do
      %__MODULE__{data | connection: conn}
    else
      {:error, websocket, reason} when is_struct(websocket, Mint.WebSocket) ->
        {:encoding_failed, reason}
        |> handle_error(data, websocket: websocket)

      {:error, conn, reason} ->
        {:casting_failed, reason}
        |> handle_error(data, connection: conn)
    end
  end

  defp handle_frame({:error, reason}, data) do
    handle_error({:decoding_failed, reason}, data)
  end

  defp handle_frame({:close, code, reason}, data) do
    log(:info, :dropping, {code, reason}, data.opts)

    code
    |> data.module.handle_disconnect(reason, data.inner_state)
    |> handle_connection_callback(data)
  end

  defp handle_frame({type, message} = frame, data) when type in [:ping, :pong] do
    data =
      if type == :ping do
        send_frame({:pong, message}, data)
      else
        data
      end

    frame
    |> data.module.handle_control(data.inner_state)
    |> handle_generic_callback(data)
  end

  defp handle_frame(frame, data) do
    frame
    |> data.module.handle_in(data.inner_state)
    |> handle_generic_callback(data)
  end

  ### ===============================================================
  ###
  ###  Generic callback functions
  ###
  ### ===============================================================

  defp handle_generic_callback({:ok, inner_state}, data) do
    %__MODULE__{data | inner_state: inner_state}
  end

  defp handle_generic_callback({:reply, response, inner_state}, data) do
    response
    |> send_frame(data)
    |> struct(inner_state: inner_state)
  end

  defp handle_generic_callback({:close, code, reason, inner_state}, data) do
    send_frame({:close, code, reason}, data)
    |> struct(inner_state: inner_state)
  end

  ### ===============================================================
  ###
  ###  Connection callback functions
  ###
  ### ===============================================================

  defp handle_error({error_type, reason} = error, data, additional \\ []) do
    log(:error, error_type, reason, data.opts)

    error
    |> data.module.handle_error(data.inner_state)
    |> handle_connection_callback(data, additional)
  end

  defp handle_connection_callback(error, data, additional \\ [])

  defp handle_connection_callback({:ignore, inner_state}, data, additional) do
    %__MODULE__{data | inner_state: inner_state, reconnect: nil}
    |> struct(additional)
  end

  defp handle_connection_callback({:reconnect, inner_state}, data, additional) do
    %__MODULE__{data | default_state: inner_state, reconnect: true}
    |> struct(additional)
  end

  defp handle_connection_callback(:reconnect, data, additional) do
    %__MODULE__{data | reconnect: true}
    |> struct(additional)
  end

  defp handle_connection_callback(:close, data, additional) do
    %__MODULE__{data | reconnect: false}
    |> struct(additional)
  end

  defp handle_connection_callback({:close, reason}, data, additional) do
    %__MODULE__{data | reconnect: {false, reason}}
    |> struct(additional)
  end

  ### ===============================================================
  ###
  ###  Data to event
  ###
  ### ===============================================================

  defp data_to_event(%__MODULE__{reconnect: true} = data) do
    reconnect(data)
  end

  defp data_to_event(%__MODULE__{reconnect: false} = data) do
    disconnect(data, :normal)
  end

  defp data_to_event(%__MODULE__{reconnect: {false, reason}} = data) do
    disconnect(data, reason)
  end

  defp data_to_event(data) do
    {:keep_state, data}
  end

  ### ===============================================================
  ###
  ###  Queue functions
  ###
  ### ===============================================================

  defp handle_response_queue(%__MODULE__{response_queue: [head | tail]} = data) do
    data = handle_response({:data, :fake_ref, head}, data)
    handle_response_queue(%__MODULE__{data | response_queue: tail})
  end

  defp handle_response_queue(%__MODULE__{response_queue: []} = data) do
    data
  end

  ### ===============================================================
  ###
  ###  Clean reconnect and disconnect
  ###
  ### ===============================================================

  defp reconnect(data) do
    disconnect(data, :normal)

    backoff_time =
      data.opts
      |> Option.backoff_max()
      |> min(data.backoff_time)

    Process.send_after(self(), :reconnect, backoff_time)

    data = %__MODULE__{
      uri: data.uri,
      opts: data.opts,
      module: data.module,
      default_state: data.default_state,
      inner_state: data.default_state,
      response_queue: [],
      backoff_time: round(backoff_time * 1.5)
    }

    {:next_state, :disconnected, data}
  end

  defp disconnect(data, reason) do
    if data.connection do
      Mint.HTTP.close(data.connection)
    end

    {:stop, reason}
  end
end
