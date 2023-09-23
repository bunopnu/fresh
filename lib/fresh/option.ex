defmodule Fresh.Option do
  @moduledoc false

  def backoff_initial(opts), do: Keyword.get(opts, :backoff_initial, 250)

  def ping_interval(opts), do: Keyword.get(opts, :ping_interval, 30_000)

  def headers(opts), do: Keyword.get(opts, :headers, [])

  def transport_opts(opts), do: Keyword.get(opts, :transport_opts, [])

  def mint_upgrade_opts(opts), do: Keyword.get(opts, :mint_upgrade_opts, [])

  def backoff_max(opts), do: Keyword.get(opts, :backoff_max, 30_000)

  def error_logging(opts), do: Keyword.get(opts, :error_logging, true)

  def info_logging(opts), do: Keyword.get(opts, :info_logging, true)

  def hibernate_after(opts), do: Keyword.get(opts, :hibernate_after, :infinity)

  def name(opts), do: Keyword.get(opts, :name)
end
