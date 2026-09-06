defmodule GPUITest.Examples do
  @moduledoc false

  defdelegate load!(name), to: GPUI.Maintainer.ExampleLoader
end
