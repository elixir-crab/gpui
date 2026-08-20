defmodule GPUI.HTMLEngine do
  @moduledoc "Phoenix HTML engine that lowers HEEx nodes into GPUI element values."

  @behaviour Phoenix.LiveView.TagEngine

  @impl Phoenix.LiveView.TagEngine
  def classify_type(":inner_block"), do: {:error, "the slot name :inner_block is reserved"}
  def classify_type(":" <> name), do: {:slot, name}

  def classify_type(<<first, _rest::binary>> = name) when first in ?A..?Z,
    do: {:remote_component, name}

  def classify_type("."), do: {:error, "a component name is required after ."}
  def classify_type("." <> name), do: {:local_component, name}
  def classify_type(name), do: {:tag, name}

  @impl Phoenix.LiveView.TagEngine
  def void?(_name), do: false

  @impl Phoenix.LiveView.TagEngine
  def handle_attributes(ast, _meta), do: {:quoted, ast}

  @impl Phoenix.LiveView.TagEngine
  def annotate_body(_caller), do: nil

  @impl Phoenix.LiveView.TagEngine
  def annotate_slot(_name, _tag_meta, _close_tag_meta, _caller), do: nil

  @impl Phoenix.LiveView.TagEngine
  def annotate_caller(_file, _line, _caller), do: nil
end
