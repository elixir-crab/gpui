defmodule Features.EditableTextSurface.View do
  use GPUI.View

  @impl GPUI.View
  def render(assigns) do
    ~GPUI"""
    <div class="flex grow flex-col w-full h-full bg-slate-900 text-white">
      <div class="flex items-center justify-between px-4 py-2 bg-slate-800 border-b border-slate-700">
        <text class="font-semibold">Editable text primitives</text>
        <text class="text-xs text-slate-400">revision {assigns.revision}</text>
      </div>
      <div class="flex grow min-h-0">
        <div class="flex w-12 flex-col items-end gap-1 py-3 pr-3 bg-slate-950 text-slate-500">
          <text class="text-sm">1</text>
          <text class="text-sm">2</text>
          <text class="text-sm">3</text>
          <text class="text-sm">4</text>
          <text class="text-sm">5</text>
        </div>
        <text_surface
          id="document"
          class="grow min-w-0 p-3 bg-slate-900 text-sm"
          buffer={assigns.buffer}
          focus_request={assigns.focus_request}
          tab_size={2}
          phx-transaction="text-transaction"
          phx-selection-change="selection-changed"
        />
      </div>
      <div class="flex items-center justify-between px-4 py-2 bg-slate-800 border-t border-slate-700">
        <text class="text-xs text-slate-400">{assigns.status}</text>
        <button phx-click="focus-editor" class="px-3 py-1 bg-blue-600 rounded">Focus</button>
      </div>
    </div>
    """
  end

  @impl GPUI.View
  def handle_event("text-transaction", %{revision: revision}, assigns),
    do: {:noreply, %{assigns | revision: revision, status: "Native transaction applied"}}

  def handle_event("selection-changed", %{value: selections}, assigns),
    do: {:noreply, %{assigns | status: "#{length(selections)} selection(s)"}}

  def handle_event("focus-editor", _event, assigns),
    do: {:noreply, %{assigns | focus_request: assigns.focus_request + 1}}
end

defmodule Features.EditableTextSurface.App do
  use GPUI.Application

  @impl GPUI.Application
  def mount(_args) do
    {:ok, buffer} =
      GPUI.Text.Buffer.new(
        "# Neutral editable text\n\nThis surface owns no file, language, gutter, or IDE policy.\nEdit me with native keyboard and IME input.\n"
      )

    assigns = %{buffer: buffer, revision: 0, focus_request: 1, status: "Ready"}

    {:ok,
     [
       window "Editable Text Surface" do
         size(760, 480)
         root(Features.EditableTextSurface.View, assigns)
       end
     ]}
  end
end
