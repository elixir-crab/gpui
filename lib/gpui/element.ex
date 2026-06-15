defmodule GPUI.Element do
  @moduledoc """
  Serializable element tree produced by `GPUI.View` modules.
  """

  @type child :: t() | String.t()
  @type t :: %__MODULE__{type: atom(), attrs: keyword(), children: [child()]}

  defstruct [:type, attrs: [], children: []]

  @doc false
  @spec append_child(t(), child()) :: t()
  def append_child(%__MODULE__{} = element, child) do
    %{element | children: element.children ++ [child]}
  end

  @doc false
  @spec put_style(t(), atom(), term()) :: t()
  def put_style(%__MODULE__{} = element, key, value) when is_atom(key) do
    styles = Keyword.get(element.attrs, :style, [])
    attrs = Keyword.put(element.attrs, :style, Keyword.put(styles, key, value))
    %{element | attrs: attrs}
  end
end
