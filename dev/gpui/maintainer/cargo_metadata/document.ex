defmodule GPUI.Maintainer.CargoMetadata.Document do
  @moduledoc "Decoded `cargo metadata` document used by maintainer tooling."

  use JSONCodec, strict: true, fast_path: :json

  defstruct [packages: [], resolve: nil]

  @type t :: %__MODULE__{
          packages: [GPUI.Maintainer.CargoMetadata.Package.t()],
          resolve: GPUI.Maintainer.CargoMetadata.Resolve.t()
        }
end
