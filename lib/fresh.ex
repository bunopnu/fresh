defmodule Fresh do
  @moduledoc "Fresh is a WebSocket client for Elixir."

  alias Fresh.Spawn

  @typedoc "Represents the state of the given module, which can be anything."
  @type state :: any()

  @typedoc "Represents various error scenarios that can occur during WebSocket communication."
  @type error ::
          {:connecting_failed, Mint.Types.error()}
          | {:upgrading_failed, Mint.WebSocket.error()}
          | {:streaming_failed, Mint.Types.error()}
          | {:establishing_failed, Mint.WebSocket.error()}
          | {:processing_failed, term()}
          | {:decoding_failed, any()}
          | {:encoding_failed, any()}
          | {:casting_failed, Mint.WebSocket.error()}

  @typedoc "Represents control frames in a WebSocket connection."
  @type control_frame :: {:ping, binary()} | {:pong, binary()}

  @typedoc "Represents data frames in a WebSocket connection."
  @type data_frame :: {:text, String.t()} | {:binary, binary()}

  @typedoc """
  Available optional configurations for WebSocket client configuration.

  - `:name`: Registers a name for the WebSocket connection, allowing you to refer to it later using a name.

    Example: `{:local, Example.WebSocket}`

  - `:headers`: A list of headers to include in the WebSocket connection request. These headers will be sent during the connection upgrade.

    Example: `{:headers, [{"Authorization", "Bearer token"}]}`

  - `:transport_opts`: Additional options to pass to the transport layer used for the WebSocket connection. Consult the [Mint.HTTP documentation](https://hexdocs.pm/mint/Mint.HTTP.html#connect/4-options) for more informations.

    Example: `{:transport_opts, [cacertfile: "/my/file"]}`

  - `:mint_upgrade_opts`: Extra options to provide to [Mint.WebSocket](https://github.com/elixir-mint/mint_web_socket) during the WebSocket upgrade process. Consult the [Mint.WebSocket documentation](https://hexdocs.pm/mint_web_socket/Mint.WebSocket.html#upgrade/5-options) for additional information.

    Example: `{:mint_upgrade_opts, [extensions: [Mint.WebSocket.PerMessageDeflate]]}`

  - `:ping_interval`: This option is used to keep connection alive by sending empty ping frames based on given time as milliseconds. By default it is set to `30000`. To disable it, set it to `0`.

    Example: `{:ping_interval, 60_000}`

  - `:error_logging`: Allowing you to turn on/off logging `t:error/0` errors. Enabled by default.

    Example: `{:error_logging, false}`

  """
  @type opts ::
          {:name, :gen_statem.server_name()}
          | {:headers, Mint.Types.headers()}
          | {:transport_opts, keyword()}
          | {:mint_upgrade_opts, keyword()}
          | {:ping_interval, non_neg_integer()}
          | {:error_logging, boolean()}

  @typedoc """
  Represents the result of a generic callback.

  - `{:ok, state}`: Indicates a successful operation, and it updates the state of the module.

    Example: `{:ok, state + 1}`, `{:ok, state}`

  - `{:reply, frames, state}`: Indicates a successful operation with a reply to the server, and it updates the state of the module.

    Example: `{:reply, [{:text, "Bousou"}, {:text, "暴走"}], state + 1}`

  """
  @type generic_handle_response ::
          {:ok, state()}
          | {:reply, list(Mint.WebSocket.frame()), state()}

  @typedoc """
  Represents the result of a connection handle (disconnect, error) callback.

  - `{:ignore, state}`: Indicates an intent to ignore and continue.

    Example: `{:ignore, state}`

  - `{:reconnect, state}`: Indicates an intent to reconnect, with given state.

    Example: `{:reconnect, 0}`

  - `{:close, reason}`: Indicates an intent to close connection, with custom reason. Can be used to force Supervisor to restart process.

    Example: `{:close, {:error, :unknown}}`

  - `:reconnect`: Indicates an intent to reconnect, with initial state.
  - `:close`: Indicates an intent to close connection normally.

  """
  @type connection_handle_response ::
          {:ignore, state()}
          | {:reconnect, state()}
          | {:close, term()}
          | :reconnect
          | :close

  @doc """
  Callback is invoked when a WebSocket connection is successfully established.

  - `status`: The status received during the connection upgrade.
  - `headers`: The headers received during the connection upgrade.

    Example: `[{"upgrade", "websocket"}, {"connection", "upgrade"}]`

  - `state`: The current state of the module.

  ## Example

      def handle_connect(_status, _headers, state) do
        payload = "{ \\"op\\": 1, \\"data\\": {} }"
        {:reply, [{:text, payload}], state}
      end

  """
  @callback handle_connect(status, headers, state()) :: generic_handle_response()
            when status: Mint.Types.status(), headers: Mint.Types.headers()

  @doc """
  Callback is invoked when a control frame is received from the server.

  - `frame`: The received WebSocket frame.
  - `state`: The current state of the module.

  ## Example

      def handle_control({:ping, message}, state) do
        IO.puts("Received ping with content: \#{message}!")
        {:ok, state}
      end

      def handle_control({:pong, message}, state) do
        IO.puts("Received pong with content: \#{message}!")
        {:ok, state}
      end

  """
  @callback handle_control(frame :: control_frame(), state()) :: generic_handle_response()

  @doc """
  Callback is invoked when a data frame is received from the server.

  - `frame`: The received WebSocket frame.
  - `state`: The current state of the module.

  ## Example

      def handle_in({:text, message}, state) do
        %{"data" => updated_data} = Jason.decode!(message)
        {:ok, updated_data}
      end

      def handle_in({:binary, _message}, state) do
        {:reply, [{:text, "i don't accept binary!"}], state}
      end

  """
  @callback handle_in(frame :: data_frame(), state()) :: generic_handle_response()

  @doc """
  Callback is invoked when an incomprehensible message is received.

  - `data`: The received message.
  - `state`: The current state of the module.

  ## Example

      def handle_info({:reply, message}, state) do
        {:reply, [{:text, message}], state}
      end

  Can be used like:

      send(:ws_conn, {:reply, "hello!"})

  """
  @callback handle_info(data :: any(), state()) :: generic_handle_response()

  @doc """
  Callback is invoked when an error occurs, allows you to define custom error handling logic to handle various scenarios gracefully.

  - `error`: The encountered error.
  - `state`: The current state of the module.

  ## Example

      def handle_error({error, _reason}, state)
          when error in [:encoding_failed, :casting_failed],
          do: {:ignore, state}

      def handle_error(_error, _state), do: :reconnect

  """
  @callback handle_error(error(), state()) :: connection_handle_response()

  @doc """
  Callback is invoked when the WebSocket connection is being disconnected.

  - `code`: The disconnection code (if available).

    Example: `1002`

  - `reason`: The reason for the disconnection (if available).

    Example: `"timeout"`

  - `state`: The current state of the module.

  ## Example

      def handle_disconnect(1002, _reason, _state), do: :reconnect
      def handle_disconnect(_code, _reason, _state), do: :close

  """
  @callback handle_disconnect(code, reason, state()) :: connection_handle_response()
            when code: non_neg_integer() | nil, reason: binary() | nil

  @doc """
  This macro simplifies the implementation of WebSocket client. It automatically configures `child_spec/1` and `start_link/1` for the module, and provides empty handlers for all required callbacks, which can be overridden.

  Starting the WebSocket client using `start_link/1` with the desired options:

      iex> Example.WebSocket.start_link(uri: "wss://example.com/socket", state: %{}, opts: [
      iex>   name: {:local, :ws_conn}
      iex> ])
      {:ok, #PID<0.233.0>}


  Starting the WebSocket client using Supervisor (recommended):

      children = [
        {Example.WebSocket,
         uri: "wss://example.com/socket",
         state: %{},
         opts: [
           name: {:local, :ws_conn}
         ]}
        # Add other child specifications...
      ]

      Supervisor.start_link(children, strategy: :one_for_one)

  """

  defmacro __using__(opts) do
    quote location: :keep do
      @behaviour Fresh

      @doc false
      def child_spec(start_opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [start_opts]},
          restart: :transient
        }
        |> Supervisor.child_spec(unquote(Macro.escape(opts)))
      end

      @doc false
      def start_link(start_opts) do
        uri = Keyword.fetch!(start_opts, :uri)
        state = Keyword.fetch!(start_opts, :state)
        opts = Keyword.get(start_opts, :opts, [])

        Fresh.start_link(uri, __MODULE__, state, opts)
      end

      @doc false
      def handle_connect(_status, _headers, state), do: {:ok, state}

      @doc false
      def handle_control(_message, state), do: {:ok, state}

      @doc false
      def handle_in(_frame, state), do: {:ok, state}

      @doc false
      def handle_info(_message, state), do: {:ok, state}

      @doc false
      def handle_error({error, _reason}, state)
          when error in [:encoding_failed, :casting_failed],
          do: {:ignore, state}

      def handle_error(_error, _state), do: :reconnect

      @doc false
      def handle_disconnect(_code, _reason, _state), do: :reconnect

      defoverridable child_spec: 1,
                     start_link: 1,
                     handle_connect: 3,
                     handle_control: 2,
                     handle_in: 2,
                     handle_info: 2,
                     handle_error: 2,
                     handle_disconnect: 3
    end
  end

  @doc """
  Starts a WebSocket connection.

  - `uri`: The URI to connect to.

    Example: `"wss://example.com/socket"`

  - `module`: The module that implementes the WebSocket client behaviour.

    Example: `Example.WebSocket`

  - `state`: The initial state to be passed to the module when it starts.

    Example: `%{}`

  - `opts`: A list of options to configure the WebSocket connection. Refer to `t:opts/0` for available options.

    Example: `[name: {:local, :ws_conn}, headers: [{"Authorization", "Bearer token"}]]`

  ## Example

      iex> Fresh.start_link("wss://example.com/socket", Example.WebSocket, %{}, name: {:local, :ws_conn})
      {:ok, #PID<0.233.0>}

  """
  @spec start_link(binary(), module(), any(), list(opts())) :: :gen_statem.start_ret()
  def start_link(uri, module, state, opts) do
    Spawn.start(:start_link, uri, module, state, opts)
  end

  @doc "Starts a WebSocket connection without linking process. Refer to `start_link/4` for more information."
  @spec start(binary(), module(), any(), list(opts())) :: :gen_statem.start_ret()
  def start(uri, module, state, opts) do
    Spawn.start(:start, uri, module, state, opts)
  end

  @doc """
  Sends a WebSocket frame to the server.

  - `pid`: The WebSocket connection process.
  - `frame`: The WebSocket frame to send.

    Example: `{:text, "hi!"}`

  ## Example

      iex> Fresh.send(:ws_conn, {:text, "hi!"})
      :ok

  """
  @spec send(:gen_statem.server_ref(), Mint.WebSocket.frame()) :: :ok
  def send(pid, frame) do
    :gen_statem.cast(pid, {:request, frame})
  end
end
