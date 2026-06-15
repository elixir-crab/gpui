defmodule GPUI.Protocol.Envelope do
  @moduledoc """
  Versioned request/response/event envelope for GPUI remote transports.

  Envelopes are the outer protocol object carried by transports. The payload is
  intentionally a plain map so the same envelope can carry runtime messages,
  health checks, and future capabilities negotiation.
  """

  @version 1

  @type id :: pos_integer() | nil
  @type kind :: :request | :response | :event
  @type status :: :ok | :error
  @type t :: %{
          required(:gpui) => 1,
          required(:id) => id(),
          required(:kind) => kind(),
          required(:op) => atom(),
          required(:payload) => map(),
          required(:meta) => map(),
          optional(:status) => status(),
          optional(:reason) => term()
        }

  @spec version() :: 1
  def version, do: @version

  @spec request(atom(), map(), keyword()) :: t()
  def request(op, payload \\ %{}, opts \\ []) when is_atom(op) and is_map(payload) do
    %{
      gpui: @version,
      id: Keyword.get_lazy(opts, :id, &next_id/0),
      kind: :request,
      op: op,
      payload: payload,
      meta: Keyword.get(opts, :meta, %{})
    }
  end

  @spec event(atom(), map(), keyword()) :: t()
  def event(op, payload \\ %{}, opts \\ []) when is_atom(op) and is_map(payload) do
    %{
      gpui: @version,
      id: Keyword.get(opts, :id),
      kind: :event,
      op: op,
      payload: payload,
      meta: Keyword.get(opts, :meta, %{})
    }
  end

  @spec ok(id(), map(), keyword()) :: t()
  def ok(id, payload \\ %{}, opts \\ []) when is_map(payload) do
    response(id, :ok, payload, opts)
  end

  @spec error(id(), term(), map(), keyword()) :: t()
  def error(id, reason, payload \\ %{}, opts \\ []) when is_map(payload) do
    response(id, :error, payload, Keyword.put(opts, :reason, reason))
  end

  @spec encode(t()) :: binary()
  def encode(envelope), do: envelope |> validate!() |> GPUI.Protocol.encode()

  @spec decode(binary()) :: t()
  def decode(payload) when is_binary(payload) do
    payload
    |> GPUI.Protocol.decode()
    |> validate!()
  end

  @spec validate!(map()) :: t()
  def validate!(
        %{gpui: @version, id: id, kind: kind, op: op, payload: payload, meta: meta} = envelope
      )
      when ((is_integer(id) and id > 0) or is_nil(id)) and kind in [:request, :response, :event] and
             is_atom(op) and is_map(payload) and is_map(meta) do
    envelope
  end

  def validate!(other) do
    raise ArgumentError, "invalid GPUI envelope: #{inspect(other)}"
  end

  defp response(id, status, payload, opts) do
    base = %{
      gpui: @version,
      id: id,
      kind: :response,
      op: Keyword.get(opts, :op, :response),
      status: status,
      payload: payload,
      meta: Keyword.get(opts, :meta, %{})
    }

    case Keyword.fetch(opts, :reason) do
      {:ok, reason} -> Map.put(base, :reason, reason)
      :error -> base
    end
  end

  defp next_id do
    System.unique_integer([:positive, :monotonic])
  end
end
