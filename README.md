# Bousou

**Bousou** (**暴走**) is a WebSocket client for Elixir, built atop the [Mint](https://github.com/elixir-mint) ecosystem.

**Bousou** is an attempt to create a light, reliable and high-level WebSocket client based on [Mint.WebSocket](https://github.com/elixir-mint/mint_web_socket).

## Key Features

**Bousou** aims to provide a straightforward, user-friendly API complete with examples and comprehensive documentation.

**Bousou** maintains an enduring connection to the server, promptly re-establishing it as soon as the server closes the connection _(or something goes wrong in general, mostly)_.

**Bousou** offers flexibility by allowing you to utilise `Mint.WebSocket` extensions and transport options, and provides access to a wide range of values.

## Installation

Package can be installed by adding `bousou` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:bousou, "~> 0.1.0"}]
end
```

## Example

Below is an example of a WebSocket module that handles incoming frames to implement a simple counter:

_Need to mention this example module contains approximately 13 lines of code._

```elixir
defmodule EchoWebSocket do
  use Bousou

  def handle_frame({:text, state}, state) do
    IO.puts("Received state: #{state}")
    IO.puts("Start counting from 1")

    {:reply, [{:text, "1"}], 0}
  end

  def handle_frame({:text, number}, _state) do
    number = String.to_integer(number)

    IO.puts("Number: #{number}")
    {:reply, [{:text, "#{number + 1}"}], number}
  end
end
```

More examples can be found inside [examples/](https://github.com/bunopnu/bousou/tree/main/examples) folder.

## Documentation

Check out [HexDocs website](https://hexdocs.pm/bousou) for documentation and API reference.

## License

**Bousou** is licensed under the MIT license.
