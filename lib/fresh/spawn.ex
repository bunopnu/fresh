defmodule Fresh.Spawn do
  @moduledoc false

  alias Fresh.Option

  def start(function, uri, module, state, opts) do
    init = {uri, state, opts, module}

    gen_statem_opts = [hibernate_after: Option.hibernate_after(opts)]

    args =
      case Option.name(opts) do
        nil ->
          [Fresh.Connection, init, gen_statem_opts]

        name ->
          [name, Fresh.Connection, init, gen_statem_opts]
      end

    apply(:gen_statem, function, args)
  end
end
