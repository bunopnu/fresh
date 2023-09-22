defmodule Fresh.Log do
  @moduledoc false

  require Logger

  def log(level, message, extra, opts) do
    formatted =
      message
      |> message_to_string(extra)
      |> add_title()

    case level do
      :info ->
        if Keyword.get(opts, :info_logging, true) do
          Logger.info(formatted)
        end

      :error ->
        if Keyword.get(opts, :error_logging, true) do
          Logger.error(formatted)
        end
    end
  end

  defp add_title(message) do
    "(Fresh) #{message}"
  end

  defp message_to_string(:established, _extra),
    do: "WebSocket connection established"

  defp message_to_string(:connecting_failed, reason),
    do: "Connecting to host failed: #{inspect(reason)}"

  defp message_to_string(:upgrading_failed, reason),
    do: "Upgrading connection to WebSocket failed: #{inspect(reason)}"

  defp message_to_string(:streaming_failed, reason),
    do: "Creating new stream for connection failed: #{inspect(reason)}"

  defp message_to_string(:establishing_failed, reason),
    do: "Establishing WebSocket connection failed: #{inspect(reason)}"

  defp message_to_string(:processing_failed, reason),
    do: "Processing upgrade request failed: #{inspect(reason)}"

  defp message_to_string(:decoding_failed, reason),
    do: "Decoding message failed: #{inspect(reason)}"

  defp message_to_string(:encoding_failed, reason),
    do: "Encoding message failed: #{inspect(reason)}"

  defp message_to_string(:casting_failed, reason),
    do: "Casting message failed: #{inspect(reason)}"

  defp message_to_string(:dropping, {code, reason}),
    do: "WebSocket connection is being closed with code #{code}: #{reason}"
end
