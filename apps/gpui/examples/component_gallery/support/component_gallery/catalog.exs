defmodule Examples.ComponentGallery.Catalog do
  @moduledoc false

  alias Examples.ComponentGallery.Stories

  @stories [
    Stories.Welcome,
    Stories.Button,
    Stories.Progress,
    Stories.Input,
    Stories.Select,
    Stories.Checkbox,
    Stories.Switch,
    Stories.Radio,
    Stories.Slider,
    Stories.Popover,
    Stories.Tooltip,
    Stories.Dialog,
    Stories.DropdownMenu,
    Stories.Tabs,
    Stories.Accordion,
    Stories.VirtualList,
    Stories.DataTable,
    Stories.Tree,
    Stories.CodeViewer
  ]

  def modules, do: @stories
  def entries, do: Enum.map(@stories, &Map.put(&1.metadata(), :module, &1))

  def fetch!(id) do
    Enum.find(entries(), &(&1.id == id)) ||
      raise ArgumentError, "unknown component story: #{inspect(id)}"
  end

  def initial_states do
    Map.new(@stories, fn module -> {module.metadata().id, module.initial_state()} end)
  end
end
