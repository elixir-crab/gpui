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

  @spec new(keyword()) :: t()
  def new(opts \\ []) when is_list(opts) do
    payload = struct!(__MODULE__, opts)
    validate!(payload)
    payload
  end

  @doc false
  @spec validate!(t()) :: :ok
  def validate!(%__MODULE__{text: text, external_paths: paths}) do
    validate_text!(text)
    validate_paths!(paths)
    :ok
  end

  @doc false
  @spec to_payload(t()) :: map()
  def to_payload(%__MODULE__{} = payload) do
    validate!(payload)
    %{text: payload.text, external_paths: Enum.uniq(payload.external_paths)}
  end

  defp validate_text!(nil), do: :ok

  defp validate_text!(text)
       when is_binary(text) and byte_size(text) <= @max_text_bytes,
       do: :ok

  defp validate_text!(_text),
    do: raise(ArgumentError, "transfer text must be UTF-8 binary data no larger than 1 MiB")

  defp validate_paths!(paths) when is_list(paths) do
    if Enum.count_until(paths, @max_paths + 1) > @max_paths do
      raise ArgumentError, "transfer payload accepts at most 64 external paths"
    end

    total =
      Enum.reduce(paths, 0, fn
        path, total when is_binary(path) and path != "" and byte_size(path) <= @max_path_bytes ->
          total + byte_size(path)

        _path, _total ->
          raise ArgumentError,
                "transfer external paths must be non-empty UTF-8 strings no larger than 4096 bytes"
      end)

    if total > @max_all_path_bytes do
      raise ArgumentError, "transfer external paths must total no more than 256 KiB"
    end
  end

  defp validate_paths!(_paths),
    do: raise(ArgumentError, "transfer external_paths must be a list")
end
