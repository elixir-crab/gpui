defmodule GPUI.Maintainer.CargoMetadata.Package do
  @moduledoc false

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

defmodule GPUI.Maintainer.CargoMetadata.Target do
  @moduledoc false

  use JSONCodec, strict: true, fast_path: :json

  defstruct crate_types: []

  @type t :: %__MODULE__{crate_types: [String.t()]}
end

defmodule GPUI.Maintainer.CargoMetadata.Resolve do
  @moduledoc false

  use JSONCodec, strict: true, fast_path: :json

  defstruct nodes: []

  @type t :: %__MODULE__{nodes: [GPUI.Maintainer.CargoMetadata.Node.t()]}
end

defmodule GPUI.Maintainer.CargoMetadata.Node do
  @moduledoc false

  use JSONCodec, strict: true, fast_path: :json

  defstruct [:id, deps: []]

  @type t :: %__MODULE__{id: String.t(), deps: [GPUI.Maintainer.CargoMetadata.Dependency.t()]}
end

defmodule GPUI.Maintainer.CargoMetadata.Dependency do
  @moduledoc false

  use JSONCodec, strict: true, fast_path: :json

  defstruct [:pkg]

  @type t :: %__MODULE__{pkg: String.t()}
end

defmodule GPUI.Maintainer.CargoMetadata.Document do
  @moduledoc false

  use JSONCodec, strict: true, fast_path: :json

  defstruct [packages: [], resolve: nil]

  @type t :: %__MODULE__{
          packages: [GPUI.Maintainer.CargoMetadata.Package.t()],
          resolve: GPUI.Maintainer.CargoMetadata.Resolve.t()
        }
end
