defmodule GPUI.Codegen.Native.Slider do
  @moduledoc "Generates slider event tracking, emission, and failed-delivery rollback."

  use RustQ.Meta,
    rust_sources: [
      "apps/gpui_components/native/src/controlled.rs",
      "apps/gpui_components/native/src/slider.rs"
    ]

  alias RustQ.Type, as: R

  @spec change_value(R.ref(SharedBinding.t(R.f64())), R.f64()) :: R.option(String.t())
  defrust change_value(binding, value) do
    case binding.lock() do
      {:ok, guard} ->
        event = guard.event.clone()

        if event.is_some() do
          guard.push_pending(value)
        end

        event

      {:error, _} ->
        none()
    end
  end

  @spec release_value(R.ref(SharedBinding.t(R.f64())), R.ref(SharedEvent.t()), R.f64()) ::
          {R.option(String.t()), boolean()}
  defrust release_value(binding, release, value) do
    event =
      case release.lock() do
        {:ok, guard} -> guard.clone()
        {:error, _} -> none()
      end

    track =
      case binding.lock() do
        {:ok, guard} ->
          if guard.event.is_none() and event.is_some() do
            guard.push_pending(value)
            true
          else
            false
          end

        {:error, _} ->
          false
      end

    {event, track}
  end

  @spec handle_slider(
          R.ref(SharedBinding.t(R.f64())),
          R.ref(SharedEvent.t()),
          R.ref(ComponentHost.t()),
          R.u64(),
          R.ref(SliderEvent.t())
        ) :: R.unit()
  defrust handle_slider(binding, release, host, window_id, event) do
    {change, event_name, value, track} =
      case event do
        enum_variant(SliderEvent, :change, value) ->
          value = number(deref(value))
          {true, change_value(binding, value), value, true}

        enum_variant(SliderEvent, :release, value) ->
          value = number(deref(value))
          {name, track} = release_value(binding, release, value)
          {false, name, value, track}
      end

    case event_name do
      {:some, name} ->
        payload =
          struct_literal(ComponentValueEvent,
            envelope: struct_literal(ComponentEventEnvelope, window_id: window_id, event: name),
            value: enum_variant(ComponentValue, :number, value)
          )

        result =
          host.emit(
            if change do
              enum_variant(ComponentEvent, :change, payload)
            else
              enum_variant(ComponentEvent, :release, payload)
            end
          )

        if result.is_err() and track do
          case binding.lock() do
            {:ok, guard} ->
              guard.pop_pending()

            {:error, _} ->
              :ok
          end
        end

      :none ->
        :ok
    end

    :ok
  end
end
