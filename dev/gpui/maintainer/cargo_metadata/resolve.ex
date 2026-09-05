defmodule GPUI.Maintainer.CargoMetadata.Resolve do
  @moduledoc "Decoded Cargo dependency-resolution graph."

  use JSONCodec, strict: true, fast_path: :json

  defstruct nodes: []

  @type t :: %__MODULE__{nodes: [GPUI.Maintainer.CargoMetadata.Node.t()]}
end
