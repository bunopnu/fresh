# Fresh

**Fresh** is an attempt to create a light, reliable and high-level WebSocket client based on [Mint.WebSocket](https://github.com/elixir-mint/mint_web_socket) 🌱

## Key Features

**Fresh** aims to provide a straightforward, user-friendly API complete with examples and comprehensive documentation.

**Fresh** maintains an enduring connection to the server, promptly re-establishing it as soon as the server closes the connection _(or something goes wrong in general)_.

**Fresh** provides almost complete control over the flow of WebSocket connections.

## Installation

Package can be installed by adding `fresh` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:fresh, "~> 0.1.0"}]
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

**Fresh** is licensed under the MIT license.
