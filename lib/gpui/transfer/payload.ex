defmodule GPUI.Transfer.Payload do
  @moduledoc """
  Bounded renderer-independent clipboard or drag/drop facts.

  External paths always refer to the machine running the display. A payload
  does not read files, infer MIME types, upload content, or assign product
  meaning to paths.
  """

  @max_text_bytes 1_048_576
  @max_paths 64
  @max_path_bytes 4_096
  @max_all_path_bytes 262_144

  @enforce_keys []
  defstruct text: nil, external_paths: []

  @type t :: %__MODULE__{
          text: String.t() | nil,
          external_paths: [String.t()]
        }

  @spec new(keyword() | map()) :: t()
  def new(opts \\ [])

  def new(opts) when is_list(opts), do: opts |> Map.new() |> new()

  def new(opts) when is_map(opts) do
    payload = struct!(__MODULE__, opts)
    paths = normalize_paths!(payload.external_paths)
    payload = %{payload | external_paths: paths}
    validate_text!(payload.text)
    payload
  end

  @doc false
  @spec validate!(t()) :: :ok
  def validate!(%__MODULE__{text: text, external_paths: paths}) do
    validate_text!(text)

    if normalize_paths!(paths) != paths do
      raise ArgumentError, "transfer external_paths must be normalized in first-seen order"
    end

    :ok
  end

  @doc false
  @spec to_payload(t()) :: map()
  def to_payload(%__MODULE__{} = payload) do
    validate!(payload)
    %{text: payload.text, external_paths: payload.external_paths}
  end

  defp validate_text!(nil), do: :ok

  defp validate_text!(text)
       when is_binary(text) and byte_size(text) <= @max_text_bytes do
    if String.valid?(text),
      do: :ok,
      else: raise(ArgumentError, "transfer text must be valid UTF-8")
  end

  defp validate_text!(_text),
    do: raise(ArgumentError, "transfer text must be UTF-8 binary data no larger than 1 MiB")

  defp normalize_paths!(paths) when is_list(paths) do
    paths =
      Enum.map(paths, fn
        path when is_binary(path) and path != "" and byte_size(path) <= @max_path_bytes ->
          if String.valid?(path),
            do: path,
            else: raise(ArgumentError, "transfer external paths must be valid UTF-8 strings")

        _path ->
          raise ArgumentError,
                "transfer external paths must be non-empty UTF-8 strings no larger than 4096 bytes"
      end)
      |> Enum.uniq()

    if length(paths) > @max_paths do
      raise ArgumentError, "transfer payload accepts at most 64 unique external paths"
    end

    if Enum.reduce(paths, 0, &(byte_size(&1) + &2)) > @max_all_path_bytes do
      raise ArgumentError, "transfer unique external paths must total no more than 256 KiB"
    end

    paths
  end

  defp normalize_paths!(_paths),
    do: raise(ArgumentError, "transfer external_paths must be a list")
end
