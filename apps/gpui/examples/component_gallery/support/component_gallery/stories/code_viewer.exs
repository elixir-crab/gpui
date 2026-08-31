defmodule Examples.ComponentGallery.Stories.CodeViewer do
  @behaviour Examples.ComponentGallery.Story
  alias Examples.ComponentGallery.Components
  alias GPUI.UI

  @impl true
  def metadata,
    do: %{
      id: "code_viewer",
      group: "Collections",
      title: "Code viewer",
      description: "Selectable semantic lines in a unified diff."
    }

  @impl true
  def initial_state, do: %{selected: nil}

  @impl true
  def render_story(state) do
    lines = [
      UI.code_line(%{
        id: "line-1",
        text: "@@ -74,6 +74,10 @@ def refresh(runtime) do",
        kind: "hunk"
      }),
      UI.code_line(%{
        id: "line-2",
        number: 74,
        text: "   snapshot = Session.snapshot(session)",
        kind: "context"
      }),
      UI.code_line(%{
        id: "line-3",
        number: 75,
        text: "-  Display.sync(display, snapshot)",
        kind: "deletion"
      }),
      UI.code_line(%{
        id: "line-4",
        number: 75,
        text: "+  with {:ok, snapshot} <- Session.refresh(session),",
        kind: "addition"
      }),
      UI.code_line(%{
        id: "line-5",
        number: 76,
        text: "+       :ok <- Display.sync(display, snapshot) do",
        kind: "addition"
      }),
      UI.code_line(%{id: "line-6", number: 77, text: "+    {:ok, snapshot}", kind: "addition"}),
      UI.code_line(%{id: "line-7", number: 78, text: "+  end", kind: "addition"})
    ]

    viewer =
      UI.code_viewer(%{
        id: "gallery-code",
        label: "Runtime diff",
        mode: "diff",
        selected: state.selected,
        reveal: state.selected,
        item_height: 34,
        max_columns: 72,
        "phx-change": "story:code_viewer:selected",
        class: "grow",
        children: lines
      })

    Components.collection_canvas("lib/gpui/runtime.ex", viewer, "w-[760px]")
  end

  @impl true
  def story_event("selected", %{value: value}, state), do: {:noreply, %{state | selected: value}}
end
