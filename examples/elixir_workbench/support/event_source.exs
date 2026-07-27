defmodule Examples.ElixirWorkbench.LogEvent do
  @moduledoc false

  @message_limit 4_096
  @metadata_limit 2_048
  @metadata_value_limit 512
  @message_detail_lines 230
  @metadata_exclusions [:gl, :time]

  def from_input(input, sequence) when is_map(input) do
    level = normalize_level(Map.get(input, :level, :info))
    message = input |> Map.get(:message, "") |> to_string() |> truncate(@message_limit)
    source = input |> Map.get(:source, "application") |> to_string() |> truncate(120)
    metadata = input |> Map.get(:metadata, %{}) |> normalize_metadata()

    build(sequence, level, message, source, metadata, Map.get(input, :timestamp))
  end

  def from_logger(%{level: level, msg: message, meta: raw_metadata}, sequence) do
    source = logger_source(raw_metadata)
    timestamp = format_logger_timestamp(Map.get(raw_metadata, :time))
    metadata = normalize_metadata(raw_metadata)

    build(
      sequence,
      normalize_level(level),
      format_logger_message(message),
      source,
      metadata,
      timestamp
    )
  end

  def row_text(event) do
    message = event.message |> String.replace(~r/\s*\R\s*/, " ↵ ") |> String.trim()
    "#{event.timestamp} #{String.upcase(event.level)} [#{event.source}] #{message}"
  end

  def detail_lines(event) do
    all_message_lines = String.split(event.message, ~r/\R/, trim: false)

    message_lines =
      if Enum.count_until(all_message_lines, @message_detail_lines + 1) > @message_detail_lines do
        Enum.take(all_message_lines, @message_detail_lines) ++ ["… additional lines omitted"]
      else
        all_message_lines
      end

    metadata_lines =
      event.metadata
      |> Enum.sort_by(fn {key, _value} -> to_string(key) end)
      |> Enum.map(fn {key, value} -> "#{key}: #{format_metadata_value(value)}" end)

    message_lines ++ [""] ++ metadata_lines
  end

  def max_columns(events) do
    events
    |> Enum.reduce(0, fn event, columns -> max(columns, String.length(row_text(event))) end)
    |> min(20_000)
  end

  defp build(sequence, level, message, source, metadata, timestamp) do
    timestamp = timestamp || "00:00:00.000"
    id = "event-#{sequence}"

    %{
      id: id,
      sequence: sequence,
      timestamp: timestamp,
      level: level,
      message: message,
      source: source,
      metadata: metadata,
      search_text:
        String.downcase(
          Enum.join(
            [message, source, level, inspect(metadata, limit: 20, printable_limit: 500)],
            " "
          )
        )
    }
  end

  defp normalize_level(level) when level in [:debug, "debug"], do: "debug"
  defp normalize_level(level) when level in [:warning, :warn, "warning", "warn"], do: "warning"

  defp normalize_level(level)
       when level in [
              :error,
              :critical,
              :alert,
              :emergency,
              "error",
              "critical",
              "alert",
              "emergency"
            ],
       do: "error"

  defp normalize_level(_level), do: "info"

  defp logger_source(metadata) do
    cond do
      metadata[:component] -> to_string(metadata.component)
      metadata[:module] -> inspect(metadata.module)
      metadata[:domain] -> metadata.domain |> List.wrap() |> Enum.map_join(".", &to_string/1)
      true -> "application"
    end
    |> truncate(120)
  end

  defp format_logger_message({:string, message}),
    do: message |> IO.chardata_to_string() |> truncate(@message_limit)

  defp format_logger_message({format, arguments}) when is_list(arguments) do
    format
    |> :io_lib.format(arguments)
    |> IO.chardata_to_string()
    |> truncate(@message_limit)
  rescue
    _error -> inspect({format, arguments}, printable_limit: @message_limit)
  end

  defp format_logger_message(message), do: inspect(message, printable_limit: @message_limit)

  defp format_logger_timestamp(time) when is_integer(time) do
    milliseconds = time |> rem(1_000_000) |> div(1_000)

    {{_year, _month, _day}, {hour, minute, second}} =
      :calendar.system_time_to_local_time(time, :microsecond)

    Enum.map_join([hour, minute, second], ":", fn value ->
      value |> Integer.to_string() |> String.pad_leading(2, "0")
    end) <> "." <> (milliseconds |> Integer.to_string() |> String.pad_leading(3, "0"))
  rescue
    _error -> "00:00:00.000"
  end

  defp format_logger_timestamp(_time), do: nil

  defp normalize_metadata(metadata) when is_map(metadata) do
    metadata
    |> Map.drop(@metadata_exclusions)
    |> Enum.take(24)
    |> Map.new(fn {key, value} -> {metadata_key(key), metadata_value(value)} end)
  end

  defp normalize_metadata(metadata) when is_list(metadata),
    do: metadata |> Map.new() |> normalize_metadata()

  defp normalize_metadata(_metadata), do: %{}

  defp metadata_key(key) when is_atom(key) or is_binary(key), do: to_string(key)
  defp metadata_key(key), do: key |> inspect(printable_limit: 120) |> truncate(120)

  defp metadata_value(value)
       when is_atom(value) or is_number(value) or is_boolean(value) or is_nil(value),
       do: value

  defp metadata_value(value) when is_binary(value), do: truncate(value, @metadata_value_limit)

  defp metadata_value(value),
    do:
      value
      |> inspect(limit: 20, printable_limit: @metadata_value_limit)
      |> truncate(@metadata_value_limit)

  defp format_metadata_value(value) do
    value
    |> inspect(limit: 20, printable_limit: @metadata_limit, width: 100)
    |> truncate(@metadata_limit)
  end

  defp truncate(value, limit) when byte_size(value) <= limit, do: value
  defp truncate(value, limit), do: String.slice(value, 0, limit) <> "…"
end

defmodule Examples.ElixirWorkbench.LogModel do
  @moduledoc false

  alias Examples.ElixirWorkbench.LogEvent, as: Event

  @max_loaded_events 256

  def prepare(events, start_sequence \\ 1) do
    events
    |> Enum.with_index(start_sequence)
    |> Enum.map(fn {event, sequence} -> Event.from_input(event, sequence) end)
  end

  def filter(events, query, level) do
    query = query |> String.trim() |> String.downcase()
    Enum.filter(events, &matches?(&1, query, level))
  end

  def matches?(event, normalized_query, level) do
    level_match? = level == "all" or event.level == level
    query_match? = normalized_query == "" or String.contains?(event.search_text, normalized_query)
    level_match? and query_match?
  end

  def snapshot(events, assigns) do
    total = length(events)
    {offset, loaded} = loaded_slice(events, assigns.range, assigns.follow)
    selected_index = selected_index(events, assigns.selected_id)
    selected_event = if selected_index, do: Enum.at(events, selected_index)
    {reveal_id, reveal_index} = reveal(events, assigns, selected_index)

    %{
      total: total,
      offset: offset,
      events: loaded,
      max_columns: Event.max_columns(events),
      selected_id: selected_event && selected_event.id,
      selected_index: selected_index,
      selected_event: selected_event,
      reveal_id: reveal_id,
      reveal_index: reveal_index
    }
  end

  def initial_range, do: %{first: 0, last: 48}

  defp loaded_slice(events, _range, true) do
    total = length(events)
    first = max(total - 48, 0)
    {first, Enum.slice(events, first, total - first)}
  end

  defp loaded_slice(events, %{first: first, last: last}, false) do
    total = length(events)
    first = first |> max(0) |> min(total)
    last = last |> max(first) |> min(total) |> min(first + @max_loaded_events)
    {first, Enum.slice(events, first, last - first)}
  end

  defp selected_index(_events, nil), do: nil
  defp selected_index(events, selected_id), do: Enum.find_index(events, &(&1.id == selected_id))

  defp reveal([], _assigns, _selected_index), do: {nil, nil}

  defp reveal(events, %{follow: true}, _selected_index) do
    index = length(events) - 1
    {Enum.at(events, index).id, index}
  end

  defp reveal(_events, assigns, selected_index) when is_integer(selected_index),
    do: {assigns.selected_id, selected_index}

  defp reveal(_events, _assigns, _selected_index), do: {nil, nil}
end
