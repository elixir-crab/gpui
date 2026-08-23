defmodule GPUI.Codegen.Native.EventBoundaryDefinitions do
  @moduledoc false

  defmacro define_inject_kind do
    type = GPUI.Event.injectable_types() |> Enum.reverse() |> Enum.reduce(&{:|, [], [&1, &2]})

    quote do
      @type inject_kind :: unquote(type)
    end
  end
end

defmodule GPUI.Codegen.Native.EventBoundary do
  @moduledoc "Defines RustQ-owned native event request and NIF boundaries."

  use RustQ.Native,
    build: false,
    load: false,
    rust_sources: ["native/gpui/src/nif.rs"]

  alias GPUI.Codegen.Native.EventBoundaryDefinitions
  alias RustQ.Type, as: R

  require EventBoundaryDefinitions
  EventBoundaryDefinitions.define_inject_kind()

  @type inject_request :: %{
          required(:event) => term()
        }

  @spec inject_request(term()) :: inject_request()
  defrust inject_request(event), do: %{event: event}

  @spec decode_inject(inject_request()) ::
          R.nif_result(
            {R.path(:InjectKind), R.u64(), R.option(String.t()),
             R.option(R.path(:EventValue))}
          )
  defrust decode_inject(request) do
    event = request.event
    kind = decode_as!(event.map_get(Atoms.type_atom()), R.path(:InjectKind))
    window_id = decode_as!(event.map_get(Atoms.window_id()), R.u64())

    event_name =
      case event.map_get(Atoms.event()) do
        {:ok, value} -> decode_as(value, String.t()).ok()
        {:error, _missing} -> nil
      end

    value =
      case event.map_get(Atoms.value()) do
        {:ok, value} -> decode_event_value(value)
        {:error, _missing} -> nil
      end

    {:ok, {kind, window_id, event_name, value}}
  end

  @spec drain_events(R.resource(R.path(:RuntimeResource))) :: R.nif_result(term())
  defnif drain_events(runtime), do: drain_events_impl(nif_env(), runtime)

  @spec inject_event(
          R.resource(R.path(:RuntimeResource)),
          term()
        ) :: R.nif_result(term())
  defnif inject_event(runtime, event) do
    inject_event_impl(nif_env(), runtime, inject_request(event))
  end
end
