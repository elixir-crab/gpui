defmodule GPUI.TestSupport.Examples do
  @moduledoc false

  defdelegate load!(name), to: GPUI.Maintainer.ExampleLoader
end
