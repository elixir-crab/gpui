defmodule GPUI.Codegen.Native.ResourceBoundary do
  @moduledoc "Defines RustQ-owned native resource request and NIF boundaries."

  use RustQ.Native,
    otp_app: :gpui_native,
    build: false,
    load: false,
    rust_sources: ["apps/gpui_native/native/gpui/src/nif.rs"]

  alias RustQ.Type, as: R

  @type put_request :: %{
          required(:resource_id) => String.t(),
          required(:resource) => term()
        }

  @type drop_request :: %{
          required(:resource_id) => String.t()
        }

  @spec put_request(String.t(), term()) :: put_request()
  defrust(put_request(resource_id, resource),
    do: %{resource_id: resource_id, resource: resource}
  )

  @spec drop_request(String.t()) :: drop_request()
  defrust(drop_request(resource_id), do: %{resource_id: resource_id})

  @nif schedule: :dirty_cpu
  @spec put_resource(
          R.resource(R.path(:RuntimeResource)),
          String.t(),
          term()
        ) :: R.nif_result(term())
  defnif put_resource(runtime, resource_id, resource) do
    put_resource_impl(nif_env(), runtime, put_request(resource_id, resource))
  end

  @spec drop_resource(
          R.resource(R.path(:RuntimeResource)),
          String.t()
        ) :: R.nif_result(term())
  defnif drop_resource(runtime, resource_id) do
    drop_resource_impl(nif_env(), runtime, drop_request(resource_id))
  end
end

defmodule GPUI.Codegen.Native.DisabledResourceBoundary do
  @moduledoc "Defines RustQ-owned resource NIF fallbacks without real GPUI."

  use RustQ.Native,
    otp_app: :gpui_native,
    build: false,
    load: false,
    rust_sources: ["apps/gpui_native/native/gpui/src/disabled.rs"]

  alias RustQ.Type, as: R

  @nif schedule: :dirty_cpu
  @spec put_resource(
          R.resource(R.path(:RuntimeResource)),
          String.t(),
          term()
        ) :: R.nif_result(term())
  defnif(put_resource(_runtime, _resource_id, _resource), do: real_gpui_disabled())

  @spec drop_resource(
          R.resource(R.path(:RuntimeResource)),
          String.t()
        ) :: R.nif_result(term())
  defnif(drop_resource(_runtime, _resource_id), do: real_gpui_disabled())
end
