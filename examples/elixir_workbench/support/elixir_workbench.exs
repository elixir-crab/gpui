Code.require_file("event_source.exs", __DIR__)
Code.require_file("log_source.exs", __DIR__)
Code.require_file("repository_workspace_source.exs", __DIR__)

defmodule Examples.ElixirWorkbench.View do
  use GPUI.View

  alias Examples.ElixirWorkbench.RepositoryTree, as: Tree
  alias Examples.ElixirWorkbench.LogEvent, as: Event
  alias GPUI.UI
  alias GPUI.UI.Overlay

  @impl GPUI.View
  def render(assigns) do
    entries =
      Tree.visible(assigns.repository.files, assigns.expanded, assigns.query, assigns.status)

    selected_id = if Enum.any?(entries, &(&1.id == assigns.selected_id)), do: assigns.selected_id
    visible_logs = visible_logs(assigns)

    ~GPUI"""
    <div class="flex grow flex-col w-full bg-[#0A1220]">
      <div class="flex items-center justify-between px-3 py-2 bg-[#111C2E]">
        <div class="flex items-center gap-3">
          <div class="flex items-center justify-center w-[28px] h-[28px] rounded-sm bg-[#F97316]"><text class="text-white font-semibold">E</text></div>
          <div class="flex min-w-0 flex-col"><text class="text-white font-semibold">Elixir Workbench</text><text class="truncate text-[#94A3B8]">{assigns.repository.name} · {assigns.repository.branch}</text></div>
        </div>
        <div class="flex items-center gap-3">
          <text class="text-[#34D399]">● Runtime connected</text>
          <UI.button id="command-palette" label="Run command" variant="primary" phx-click="command-palette" />
        </div>
      </div>

      <div class="flex min-h-0 h-[820px]">
        <div class="flex min-h-0 flex-col w-[260px] bg-[#0D1727]">
          <div class="flex flex-col gap-2 p-2">
            <UI.input id="file-filter" label="Filter files" value={assigns.query} placeholder="Filter project" cleanable={true} phx-change="filter_changed" />
            <UI.select id="status-filter" label="File status" value={assigns.status} options={[{"All files", "all"}, {"Changed", "modified"}, {"Untracked", "untracked"}, {"Clean", "clean"}]} phx-change="status_changed" />
          </div>
          <div class="flex items-center justify-between px-4 py-2"><text class="text-[#94A3B8]">EXPLORER</text><text class="text-[#F97316]">{length(entries)}</text></div>
          <div class="flex flex-col h-[650px]">{repository_tree(entries, selected_id, assigns.expanded)}</div>
          <div class="flex flex-col gap-2 p-3 bg-[#111C2E]">
            <div class="flex justify-between"><text class="text-white">Working tree</text><text class="text-[#F59E0B]">{assigns.repository.counts.changed} changed</text></div>
            <text class="truncate text-[#64748B]">{assigns.repository.counts.total} tracked and untracked files</text>
          </div>
        </div>

        <div class="flex grow min-h-0 flex-col">
          <div class="flex items-center justify-between px-4 py-2 bg-[#172236]">
            <div class="flex min-w-0 items-center gap-3"><text class="truncate text-white">{preview_title(assigns.preview)}</text><text style={[color: status_color(assigns.preview.status)]}>{status_label(assigns.preview.status)}</text></div>
            <UI.copy_button id="copy-path" label="Copy path" text={assigns.preview.path} phx-click="path_copied" />
          </div>
          <div class="flex h-[510px]">{code_panel(assigns)}</div>

          <div class="flex flex-col h-[220px] bg-[#0B1321]">
            <div class="flex items-center justify-between px-4 py-2 bg-[#111C2E]">
              <div class="flex items-center gap-4"><text class="text-white font-semibold">Runtime console</text><text class="text-[#94A3B8]">{length(visible_logs)} events</text></div>
              <div class="flex items-center gap-3"><UI.select id="log-level" label="Log level" value={assigns.log_level} options={[{"All", "all"}, {"Errors", "error"}, {"Warnings", "warning"}, {"Info", "info"}]} phx-change="log_level_changed" /><UI.button id="clear-logs" label="Clear" phx-click="clear-logs" /></div>
            </div>
            {log_console(visible_logs, assigns.log_selected)}
          </div>
        </div>

        <scroll class="flex min-h-0 flex-col w-[290px] gap-3 p-3 bg-[#0D1727]">
          <div class="flex flex-col gap-3">
            <text class="text-white text-lg font-semibold">File context</text>
            {context_detail("Path", assigns.preview.path)}
            {context_detail("Mode", Atom.to_string(assigns.preview.mode))}
            {context_detail("Status", status_label(assigns.preview.status))}
            {context_detail("Lines", length(assigns.preview.lines))}
          </div>
          <div class="flex flex-col gap-3 p-4 rounded-lg bg-[#142238]">
            <text class="text-white font-semibold">Diagnostics</text>
            <div class="flex items-center justify-between"><text class="text-[#94A3B8]">Errors</text><text class="text-[#34D399]">0</text></div>
            <div class="flex items-center justify-between"><text class="text-[#94A3B8]">Warnings</text><text class="text-[#F59E0B]">2</text></div>
            <div class="flex items-center justify-between"><text class="text-[#94A3B8]">Tests</text><text class="text-[#38BDF8]">166 passing</text></div>
          </div>
          {selected_log(assigns)}
        </scroll>
      </div>

      <Overlay.dialog id="workbench-command" open={assigns.command_open} title="Run project command" width={480} phx-change="command_changed">
        <:content><div class="flex flex-col gap-3 p-2"><UI.input id="command-query" label="Command" value="mix test" phx-change="noop" /><div class="flex flex-col gap-2"><UI.button id="run-tests" label="mix test" variant="primary" phx-click="run-tests" /><UI.button id="run-format" label="mix format --check-formatted" phx-click="run-format" /><UI.button id="run-ci" label="mix ci" phx-click="run-ci" /></div></div></:content>
      </Overlay.dialog>
    </div>
    """
  end

  @impl GPUI.View
  def handle_event("filter_changed", %{value: value}, assigns),
    do: {:noreply, %{assigns | query: value}}

  def handle_event("status_changed", %{value: value}, assigns),
    do: {:noreply, %{assigns | status: value}}

  def handle_event("file_selected", %{value: value}, assigns),
    do: {:noreply, select_file(assigns, value)}

  def handle_event("directory_toggled", %{value: "dir:" <> path}, assigns),
    do: {:noreply, %{assigns | expanded: toggle(assigns.expanded, path)}}

  def handle_event("line_selected", %{value: value}, assigns),
    do: {:noreply, %{assigns | line_selected: value}}

  def handle_event("log_selected", %{value: value}, assigns),
    do: {:noreply, %{assigns | log_selected: value}}

  def handle_event("log_level_changed", %{value: value}, assigns),
    do: {:noreply, %{assigns | log_level: value}}

  def handle_event("clear-logs", _event, assigns),
    do: {:noreply, %{assigns | logs: [], log_selected: nil}}

  def handle_event("command-palette", _event, assigns),
    do: {:noreply, %{assigns | command_open: true}}

  def handle_event("command_changed", %{value: value}, assigns),
    do: {:noreply, %{assigns | command_open: value}}

  def handle_event("run-" <> command, _event, assigns),
    do: {:noreply, %{assigns | command_open: false, last_command: command}}

  def handle_event("path_copied", _event, assigns), do: {:noreply, %{assigns | path_copied: true}}
  def handle_event("noop", _event, assigns), do: {:noreply, assigns}

  defp repository_tree(entries, selected, expanded) do
    items =
      Enum.map(entries, fn entry ->
        UI.tree_item(%{
          id: entry.id,
          parent_id: entry.parent_id,
          level: entry.level,
          branch: entry.kind == :directory,
          expanded: entry.kind == :directory and MapSet.member?(expanded, entry.path),
          position: entry.position,
          set_size: entry.set_size,
          style: [color: {:rgb, 0xCBD5E1}],
          children: [entry_label(entry)]
        })
      end)

    UI.tree(%{
      id: "workbench-tree",
      label: "Repository files",
      selected: selected,
      reveal: selected,
      item_height: 28,
      "phx-change": "file_selected",
      "phx-toggle": "directory_toggled",
      class: "h-[650px]",
      children: items
    })
  end

  defp entry_label(entry), do: status_marker(entry.status) <> " " <> entry.name
  defp status_marker(:modified), do: "●"
  defp status_marker(:untracked), do: "+"
  defp status_marker(:added), do: "+"
  defp status_marker(:deleted), do: "−"
  defp status_marker(:directory), do: "▸"
  defp status_marker(_status), do: " "

  defp code_panel(assigns) do
    lines =
      Enum.map(assigns.preview.lines, fn line ->
        UI.code_line(%{
          id: line.id,
          number: line.number,
          text: line.text,
          kind: code_kind(line.kind)
        })
      end)

    UI.code_viewer(%{
      id: "workbench-code",
      label: "Source preview",
      mode: if(assigns.preview.mode == :diff, do: "diff", else: "plain"),
      selected: assigns.line_selected,
      reveal: assigns.line_selected,
      item_height: 22,
      max_columns: 140,
      "phx-change": "line_selected",
      class: "h-[510px]",
      children: lines
    })
  end

  defp log_console([], _selected), do: empty_console()

  defp log_console(logs, selected) do
    lines =
      Enum.map(logs, fn event ->
        UI.code_line(%{id: event.id, text: Event.row_text(event), kind: event.level})
      end)

    UI.code_viewer(%{
      id: "workbench-logs",
      label: "Runtime events",
      selected: selected,
      reveal: selected,
      item_height: 22,
      max_columns: 160,
      "phx-change": "log_selected",
      class: "h-[160px]",
      children: lines
    })
  end

  defp empty_console do
    ~GPUI"""
    <div class="flex grow items-center justify-center"><text class="text-[#64748B]">Console cleared</text></div>
    """
  end

  defp selected_log(assigns) do
    case Enum.find(assigns.logs, &(&1.id == assigns.log_selected)) do
      nil -> empty_log_detail()
      event -> log_detail(event)
    end
  end

  defp empty_log_detail do
    ~GPUI"""
    <div class="flex flex-col gap-2 p-4 rounded-lg bg-[#142238]"><text class="text-white font-semibold">Event details</text><text class="text-[#94A3B8]">Select a console event.</text></div>
    """
  end

  defp log_detail(event) do
    assigns = %{event: event}

    ~GPUI"""
    <div class="flex flex-col gap-2 p-4 rounded-lg bg-[#142238]"><text class="text-white font-semibold">{String.upcase(assigns.event.level)}</text><text class="truncate text-[#38BDF8]">{assigns.event.source}</text><text class="text-[#CBD5E1]">{assigns.event.message}</text></div>
    """
  end

  defp context_detail(label, value) do
    assigns = %{label: label, value: value}

    ~GPUI"""
    <div class="flex min-w-0 flex-col gap-1"><text class="text-[#64748B]">{assigns.label}</text><text class="truncate text-white">{assigns.value}</text></div>
    """
  end

  defp visible_logs(assigns),
    do:
      if(assigns.log_level == "all",
        do: assigns.logs,
        else: Enum.filter(assigns.logs, &(&1.level == assigns.log_level))
      )

  defp select_file(assigns, "file:" <> path = id) do
    preview = Map.get(assigns.previews, path, notice_preview(path))
    %{assigns | selected_id: id, preview: preview, line_selected: nil}
  end

  defp select_file(assigns, _directory), do: assigns

  defp toggle(set, path),
    do: if(MapSet.member?(set, path), do: MapSet.delete(set, path), else: MapSet.put(set, path))

  defp preview_title(%{path: path}), do: Path.basename(path)

  defp status_label(status) when is_atom(status),
    do: status |> Atom.to_string() |> String.capitalize()

  defp status_color(:modified), do: {:rgb, 0xF59E0B}
  defp status_color(:untracked), do: {:rgb, 0x34D399}
  defp status_color(_status), do: {:rgb, 0x94A3B8}
  defp code_kind(:notice), do: "info"

  defp code_kind(kind) when kind in [:context, :addition, :deletion, :hunk],
    do: Atom.to_string(kind)

  defp code_kind(_kind), do: "context"

  defp notice_preview(path),
    do: %{
      path: path,
      mode: :notice,
      status: :clean,
      lines: [
        %{
          id: "notice",
          number: nil,
          text: "Preview is not loaded in this deterministic workbench session.",
          kind: :notice
        }
      ]
    }
end

defmodule Examples.ElixirWorkbench.App do
  use GPUI.Application

  @impl GPUI.Application
  def mount(args) do
    args = Map.new(args)
    repository = Map.fetch!(args, :repository)
    previews = Map.fetch!(args, :previews)
    logs = Map.get(args, :logs, []) |> Examples.ElixirWorkbench.LogModel.prepare()

    initial_path =
      Map.get(args, :selected_path) || repository.files |> List.first() |> Map.fetch!(:path)

    selected_id = "file:" <> initial_path

    {:ok,
     [
       window "Elixir Workbench" do
         size(1440, 900)

         root(Examples.ElixirWorkbench.View,
           repository: repository,
           previews: previews,
           preview: Map.fetch!(previews, initial_path),
           selected_id: selected_id,
           expanded: Examples.ElixirWorkbench.RepositoryTree.default_expanded(repository.files),
           query: "",
           status: "all",
           line_selected: nil,
           logs: logs,
           log_level: "all",
           log_selected: nil,
           command_open: false,
           last_command: nil,
           path_copied: false
         )
       end
     ]}
  end
end
