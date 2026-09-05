defmodule GPUI.Maintainer.CargoMetadata.Dependency do
  @moduledoc "One resolved package dependency in decoded Cargo metadata."

  use JSONCodec, strict: true, fast_path: :json

  defstruct [:pkg]

  @type t :: %__MODULE__{pkg: String.t()}
end

