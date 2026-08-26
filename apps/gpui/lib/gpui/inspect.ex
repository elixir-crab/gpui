defimpl Inspect, for: GPUI.Element do
  import Inspect.Algebra

  def inspect(element, opts) do
    concat([
      "#GPUI.Element<",
      to_doc(element.type, opts),
      " attrs=",
      to_string(length(element.attrs)),
      " children=",
      to_string(length(element.children)),
      ">"
    ])
  end
end

defimpl Inspect, for: GPUI.Raster do
  import Inspect.Algebra

  def inspect(raster, _opts) do
    concat([
      "#GPUI.Raster<",
      to_string(raster.width),
      "x",
      to_string(raster.height),
      " ",
      to_string(raster.format),
      " bytes=",
      to_string(byte_size(raster.data)),
      stride(raster.stride),
      ">"
    ])
  end

  defp stride(nil), do: ""
  defp stride(stride), do: " stride=#{stride}"
end

defimpl Inspect, for: GPUI.WindowSpec do
  import Inspect.Algebra

  def inspect(window, opts) do
    concat([
      "#GPUI.WindowSpec<",
      "id=",
      inspect_optional(window.id, opts),
      " key=",
      inspect_optional(window.key, opts),
      " title=",
      to_doc(window.title, opts),
      " size=",
      inspect_optional(window.size, opts),
      " root=",
      inspect_root(window.root, opts),
      ">"
    ])
  end

  defp inspect_optional(nil, _opts), do: "nil"
  defp inspect_optional(value, opts), do: to_doc(value, opts)

  defp inspect_root(nil, _opts), do: "nil"
  defp inspect_root({module, _assigns}, opts), do: to_doc(module, opts)
end

defimpl Inspect, for: GPUI.Remote.Transport.TCP.Listener do
  import Inspect.Algebra

  def inspect(listener, _opts) do
    concat(["#GPUI.Remote.Transport.TCP.Listener<", to_string(listener.mode), ">"])
  end
end

defimpl Inspect, for: GPUI.Remote.Transport.TCP.Connection do
  import Inspect.Algebra

  def inspect(conn, _opts) do
    concat(["#GPUI.Remote.Transport.TCP.Connection<", to_string(conn.mode), ">"])
  end
end
