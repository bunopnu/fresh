# Fresh

Fresh is an attempt to create a simple, reliable and flexible WebSocket client based on [Mint.WebSocket](https://github.com/elixir-mint/mint_web_socket) 🌱

> ⚠️ WORK IN PROGRESS ⚠️
>
> I recommend using an alternative WebSocket client such as [WebSockex](https://github.com/Azolo/websockex) until we have finished adding tests to identify and resolve potential common issues.

## Why Fresh?

Discover the reasons behind choosing Fresh over existing libraries, summed up in three key aspects:

- Simplicity
- Resilience
- Control

### Simplicity

Fresh is designed with simplicity in mind, offering a user-friendly API that includes clear examples and comprehensive documentation.

### Resilience

Fresh excels in ensuring a robust and enduring connection to the server. By default, Fresh promptly re-establishing connection when the server terminates the connection or encounters any connectivity issues. When used alongside Supervisor, Fresh delivers exceptional reliability.

### Control

With Fresh, you gain extensive control over the flow of WebSocket connections, including control over resilience. You can manage scenarios requiring reconnection, identify those that should be ignored, specify when to gracefully terminate a connection, and even instruct Supervisor to restart your process as needed. Additionally, Fresh allows you to leverage custom `Mint.WebSocket` options, transport layer options, custom headers, and more, providing you with the flexibility you require.

## Installation

Package can be installed by adding `fresh` to your list of dependencies in `mix.exs`:

```elixir
defp deps do
  [
    {:fresh, "~> 0.1.0-rc"}
  ]
end
```

## Example

Below is an example of a WebSocket client that handles incoming frames to implement a simple counter:

_Need to mention this example module contains approximately 15 lines of code._

```elixir
defmodule EchoWebSocket do
  use Fresh

  def handle_connect(_status, _headers, _state) do
    IO.puts("Start counting from 0")
    {:reply, [{:text, "1"}], 0}
  end

  def handle_in({:text, number}, _state) do
    number = String.to_integer(number)

    IO.puts("Number: #{number}")
    {:reply, [{:text, "#{number + 1}"}], number}
  end
end
```

More examples can be found inside [examples/](https://github.com/bunopnu/fresh/tree/main/examples) folder.

## Documentation

Check out [HexDocs website](https://hexdocs.pm/fresh) for documentation and API reference.

## License

Fresh is licensed under the MIT license.
