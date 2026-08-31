defmodule GPUI.Dev.CargoMetadata.Package do
  @moduledoc false

  use JSONCodec, strict: true, fast_path: :json

  defstruct [:id, :name, :version, :license, targets: []]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          version: String.t(),
          license: String.t() | nil,
          targets: [GPUI.Dev.CargoMetadata.Target.t()]
        }
end

defmodule GPUI.Dev.CargoMetadata.Target do
  @moduledoc false

  use JSONCodec, strict: true, fast_path: :json

  defstruct crate_types: []

  @type t :: %__MODULE__{crate_types: [String.t()]}
end

defmodule GPUI.Dev.CargoMetadata.Resolve do
  @moduledoc false

  use JSONCodec, strict: true, fast_path: :json

  defstruct nodes: []

  @type t :: %__MODULE__{nodes: [GPUI.Dev.CargoMetadata.Node.t()]}
end

defmodule GPUI.Dev.CargoMetadata.Node do
  @moduledoc false

  use JSONCodec, strict: true, fast_path: :json

  defstruct [:id, deps: []]

  @type t :: %__MODULE__{id: String.t(), deps: [GPUI.Dev.CargoMetadata.Dependency.t()]}
end

defmodule GPUI.Dev.CargoMetadata.Dependency do
  @moduledoc false

  use JSONCodec, strict: true, fast_path: :json

  defstruct [:pkg]

  @type t :: %__MODULE__{pkg: String.t()}
end

defmodule GPUI.Dev.CargoMetadata.Document do
  @moduledoc false

  use JSONCodec, strict: true, fast_path: :json

  defstruct [packages: [], resolve: nil]

  @type t :: %__MODULE__{
          packages: [GPUI.Dev.CargoMetadata.Package.t()],
          resolve: GPUI.Dev.CargoMetadata.Resolve.t()
        }
end
