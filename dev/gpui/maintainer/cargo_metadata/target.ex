defmodule GPUI.Maintainer.CargoMetadata.Target do
  @moduledoc "Decoded Cargo target metadata used by repository validation."

  use JSONCodec, strict: true, fast_path: :json

  defstruct crate_types: []

  @type t :: %__MODULE__{crate_types: [String.t()]}
end

