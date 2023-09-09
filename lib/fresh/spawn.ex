defmodule Fresh.Spawn do
  @moduledoc false

  def start(function, uri, module, state, opts) do
    init = {uri, state, opts, module}

    args =
      case Keyword.get(opts, :name) do
        nil ->
          [Fresh.Connection, init, []]

        name ->
          [name, Fresh.Connection, init, []]
      end

    apply(:gen_statem, function, args)
  end
end
