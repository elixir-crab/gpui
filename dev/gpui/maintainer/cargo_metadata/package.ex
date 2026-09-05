defmodule GPUI.Maintainer.CargoMetadata.Package do
  @moduledoc "Decoded Cargo package metadata used by repository validation."

  use JSONCodec, strict: true, fast_path: :json

  defstruct [:id, :name, :version, :license, targets: []]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          version: String.t(),
          license: String.t() | nil,
          targets: [GPUI.Maintainer.CargoMetadata.Target.t()]
        }
end

