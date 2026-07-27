defmodule GPUITest.Examples do
  @moduledoc false

  defdelegate load!(name), to: GPUI.Dev.ExampleLoader
end
