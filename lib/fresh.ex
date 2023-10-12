defmodule Fresh do
  @moduledoc """
  This module provides a high-level interface for managing WebSocket connections.

  It simplifies implementing WebSocket clients, allowing you to easily establish and manage connections with WebSocket servers.

  ## Usage

  To use this module, follow these steps:

  1. Use the `use Fresh` macro in your WebSocket client module to automatically configure the necessary callbacks and functionality:

         defmodule MyWebSocketClient do
           use Fresh

           # ...callbacks and functionalities.
         end

  2. Implement callback functions to handle connection events, received data frames, and more, as specified in the documentation.

  3. Start WebSocket connections using `start_link/1` or `start/1` with the desired configuration options:

         MyWebSocketClient.start_link(uri: "wss://example.com/socket", state: %{}, opts: [
           name: {:local, :my_connection}
         ])

  ## How to Supervise

  For effective management of WebSocket connections, consider supervising your WebSocket client processes.
  You can add your WebSocket client module as a child to a supervisor, allowing the supervisor to monitor and restart the WebSocket client process in case of failures.

      children = [
        {MyWebSocketClient,
         uri: "wss://example.com/socket",
         state: %{},
         opts: [
           name: {:local, :my_connection}
         ]}

        # ...other child specifications
      ]

      Supervisor.start_link(children, strategy: :one_for_one)

  ## Reconnection

  In scenarios where the WebSocket connection is lost or encounters an error, you can configure reconnection behaviour using `c:handle_disconnect/3` and `c:handle_error/2` callbacks.
  Depending on your requirements, you can implement logic to automatically reconnect to the server or take other appropriate actions.

  ### Automatic Reconnection and Backoff

  Fresh uses exponential backoff (with a fixed factor of `1.5`) strategy for reconnection attempts.
  This means that after a connection loss, it waits for a brief interval before attempting to reconnect, gradually increasing the time between reconnection attempts until a maximum limit is reached.

  The exponential backoff strategy helps prevent overwhelming the server with rapid reconnection attempts and allows for a more graceful recovery when the server is temporarily unavailable.

  The default backoff parameters are as follows:

  * Initial Backoff Interval: 250 milliseconds
  * Maximum Backoff Interval: 30 seconds

  You can customize these parameters by including them in your WebSocket client's configuration, as shown in the "Example Configuration" section of the `t:option/0` documentation.
  """

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
  Represents optional configurations for WebSocket connections. Available options include:

  * `:name` - Registers a name for the WebSocket connection, allowing you to refer to it later using a name.
  * `:headers` - Specifies a list of headers to include in the WebSocket connection request. These headers will be sent during the connection upgrade.
  * `:transport_opts` - Additional options to pass to the transport layer used for the WebSocket connection. Consult the [Mint.HTTP documentation](https://hexdocs.pm/mint/Mint.HTTP.html#connect/4-options) for more informations.
  * `:mint_upgrade_opts` - Extra options to provide to [Mint.WebSocket](https://github.com/elixir-mint/mint_web_socket) during the WebSocket upgrade process. Consult the [Mint.WebSocket documentation](https://hexdocs.pm/mint_web_socket/Mint.WebSocket.html#upgrade/5-options) for additional information.
  * `:ping_interval` - This option is used for keeping the WebSocket connection alive by sending empty ping frames at regular intervals, specified in milliseconds. The default value is `30000` (30 seconds). To disable ping frames, set this option to `0`.
  * `:error_logging` - Allows toggling logging for error messages. Enabled by default.
  * `:info_logging` - Allows toggling logging for informational messages. Enabled by default.
  * `:backoff_initial` - Specifies the initial backoff time, in milliseconds, used between reconnection attempts. The default value is `250` (250 milliseconds).
  * `:backoff_max` - Sets the maximum time interval, in milliseconds, used between reconnection attempts. The default value is `30000` (30 seconds).
  * `:hibernate_after` - Specifies a timeout value, in milliseconds, which the WebSocket connection process will enter hibernation if there is no activity. Hibernation is disabled by default.

  ## Example Configuration

      [
        name: {:local, Example.Connection},
        headers: [{"Authorization", "Bearer token"}],
        ping_interval: 60_000,
        error_logging: false,
        backoff_initial: 5_000,
        backoff_max: 60_000,
        hibernate_after: 600_000
      ]

  """
  @type option ::
          {:name, :gen_statem.server_name()}
          | {:headers, Mint.Types.headers()}
          | {:transport_opts, keyword()}
          | {:mint_upgrade_opts, keyword()}
          | {:ping_interval, non_neg_integer()}
          | {:error_logging, boolean()}
          | {:info_logging, boolean()}
          | {:backoff_initial, non_neg_integer()}
          | {:backoff_max, non_neg_integer()}
          | {:hibernate_after, timeout()}

  @typedoc "Represents the response of a generic callback and enables you to manage the state."
  @type generic_handle_response ::
          {:ok, state()}
          | {:reply, Mint.WebSocket.frame() | [Mint.WebSocket.frame()], state()}
          | {:close, code :: non_neg_integer(), reason :: binary(), state()}

  @typedoc "Represents the response for all connection handle callbacks."
  @type connection_handle_response ::
          {:ignore, state()}
          | {:reconnect, initial :: state()}
          | {:close, reason :: term()}
          | :reconnect
          | :close

  @doc """
  Callback invoked when a WebSocket connection is successfully established.

  ## Parameters

  * `status` - The status received during the connection upgrade.
  * `headers` - The headers received during the connection upgrade.
  * `state` - The current state of the module.

  ## Example

      def handle_connect(_status, _headers, state) do
        payload = "connection up!"
        {:reply, [{:text, payload}], state}
      end

  """
  @callback handle_connect(status, headers, state()) :: generic_handle_response()
            when status: Mint.Types.status(), headers: Mint.Types.headers()

  @doc """
  Callback invoked when a control frame is received from the server.

  ## Parameters

  * `frame` - The received WebSocket frame, which is a control frame.
  * `state` - The current state of the module.

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
  Callback invoked when a data frame is received from the server.

  ## Parameters

  * `frame` - The received WebSocket frame, which is a data frame.
  * `state` - The current state of the module.

  ## Example

      def handle_in({:text, message}, state) do
        %{"data" => updated_data} = Jason.decode!(message)
        {:ok, updated_data}
      end

      def handle_in({:binary, _message}, state) do
        {:reply, [{:text, "i prefer text :)"}], state}
      end

  """
  @callback handle_in(frame :: data_frame(), state()) :: generic_handle_response()

  @doc """
  Callback invoked when an incomprehensible message is received.

  ## Parameters

  * `data` - The received message, which can be any term.
  * `state` - The current state of the module.

  ## Example

      def handle_info({:reply, message}, state) do
        {:reply, [{:text, message}], state}
      end

    Later can be used like:

      send(:ws_conn, {:reply, "hello!"})

  """
  @callback handle_info(data :: any(), state()) :: generic_handle_response()

  @doc """
  Callback invoked when an error is encountered during WebSocket communication, allowing you to define custom error handling logic for various scenarios.

  ## Parameters

  * `error` - The encountered error.
  * `state` - The current state of the module.

  ## Example

      def handle_error({error, _reason}, state)
          when error in [:encoding_failed, :casting_failed],
          do: {:ignore, state}

      def handle_error(_error, _state), do: :reconnect

  """
  @callback handle_error(error(), state()) :: connection_handle_response()

  @doc """
  Callback invoked when the WebSocket connection is being disconnected.

  ## Parameters

  * `code` (optional) - The disconnection code, if available. It should be a non-negative integer.
  * `reason` (optional) - The reason for the disconnection, if available. It should be a binary.
  * `state` - The current state of the module.

  ## Example

      def handle_disconnect(1002, _reason, _state), do: :reconnect
      def handle_disconnect(_code, _reason, _state), do: :close

  """
  @callback handle_disconnect(code, reason, state()) :: connection_handle_response()
            when code: non_neg_integer() | nil, reason: binary() | nil

  @doc """
  Callback invoked when the WebSocket process is about to terminate.

  The return value of this callback is always disregarded.

  ## Parameters

  * `reason` - The reason for the termination. It can be any term.
  * `state` - The current state of the module.

  ## Example

      def handle_terminate(reason, _state) do
        IO.puts("Process is terminating with reason: \#{inspect(reason)}")
      end

  """
  @doc since: "0.2.0"
  @callback handle_terminate(reason :: any(), state()) :: ignored :: any()

  @doc """
  This macro simplifies the implementation of WebSocket client.

  It automatically configures `child_spec/1`, `start/1` and `start_link/1` for the module, and provides handlers for all required callbacks, which can be overridden.
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
      def start(start_opts) do
        uri = Keyword.fetch!(start_opts, :uri)
        state = Keyword.fetch!(start_opts, :state)
        opts = Keyword.get(start_opts, :opts, [])

        Fresh.start(uri, __MODULE__, state, opts)
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

      @doc false
      def handle_terminate(_reason, _state), do: :ok

      defoverridable child_spec: 1,
                     start_link: 1,
                     handle_connect: 3,
                     handle_control: 2,
                     handle_in: 2,
                     handle_info: 2,
                     handle_error: 2,
                     handle_disconnect: 3,
                     handle_terminate: 2
    end
  end

  @doc """
  Starts a WebSocket connection and links the process.

  ## Parameters

  * `uri` - The URI to connect to as a binary.
  * `module` - The module that implements the WebSocket client behaviour.
  * `state` - The initial state to be passed to the module when it starts.
  * `opts` - A list of options to configure the WebSocket connection. Refer to `t:option/0` for available options.

  ## Example

      iex> Fresh.start_link("wss://example.com/socket", Example.WebSocket, %{}, name: {:local, :ws_conn})
      {:ok, #PID<0.233.0>}

  """
  @spec start_link(binary(), module(), any(), list(option())) :: :gen_statem.start_ret()
  def start_link(uri, module, state, opts) do
    Spawn.start(:start_link, uri, module, state, opts)
  end

  @doc """
  Starts a WebSocket connection without linking the process.

  This function is similar to `start_link/4` but does not link the process. Refer to `start_link/4` for parameters details.
  """
  @spec start(binary(), module(), any(), list(option())) :: :gen_statem.start_ret()
  def start(uri, module, state, opts) do
    Spawn.start(:start, uri, module, state, opts)
  end

  @doc """
  Sends a WebSocket frame to the server.

  ## Parameters

  * `pid` - The reference to the WebSocket connection process.
  * `frame` - The WebSocket frame to send.

  ## Returns

  This function always returns `:ok`.

  ## Example

      iex> Fresh.send(:ws_conn, {:text, "hi!"})
      :ok

  """
  @spec send(:gen_statem.server_ref(), Mint.WebSocket.frame()) :: :ok
  def send(pid, frame) do
    :gen_statem.cast(pid, {:request, frame})
  end

  @doc """
  Sends a WebSocket close frame to the server.

  ## Parameters

  * `pid` - The reference to the WebSocket connection process.
  * `code` - An integer representing the WebSocket close code.
  * `reason` - A binary string providing the reason for closing the WebSocket connection.

  ## Returns

  This function always returns `:ok`.

  ## Example

      iex> Fresh.close(:ws_conn, 1000, "Normal Closure")
      :ok

  """
  @doc since: "0.2.1"
  @spec close(:gen_statem.server_ref(), non_neg_integer(), binary()) :: :ok
  def close(pid, code, reason) do
    __MODULE__.send(pid, {:close, code, reason})
  end

  @doc """
  Checks if the connection is available.

  ## Parameters

  * `pid` - The reference to the WebSocket connection process.

  ## Returns

  A `t:boolean/0` representing the state of the connection.

  ## Example

      iex> Fresh.open?(:ws_conn)
      true

  """
  @doc since: "0.4.2"
  @spec open?(:gen_statem.server_ref()) :: boolean()
  def open?(pid) do
    :gen_statem.call(pid, :available)
  end
end
