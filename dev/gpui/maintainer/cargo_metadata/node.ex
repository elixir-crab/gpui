defmodule GPUI.Maintainer.CargoMetadata.Node do
  @moduledoc "One package node in a decoded Cargo dependency-resolution graph."

  use JSONCodec, strict: true, fast_path: :json

  defstruct [:id, deps: []]

  @type t :: %__MODULE__{id: String.t(), deps: [GPUI.Maintainer.CargoMetadata.Dependency.t()]}
end
