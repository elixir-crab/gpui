Code.require_file("repository.exs", __DIR__)

defmodule Examples.GitRepositoryBrowser.Tree do
  @moduledoc false

  def visible(files, expanded, filter, status_filter) do
    files = filter_files(files, filter, status_filter)
    directories = directories(files)

    (directories ++ Enum.map(files, &file_entry/1))
    |> Enum.sort_by(&sort_key/1)
    |> Enum.filter(&visible?(&1, expanded))
    |> annotate_accessibility()
  end

  def default_expanded(files) do
    files
    |> directories()
    |> Enum.filter(&(&1.depth == 0))
    |> Enum.map(& &1.path)
    |> MapSet.new()
  end

  def selected_id(entries, selected_id) do
    if Enum.any?(entries, &(&1.id == selected_id)), do: selected_id
  end

  defp filter_files(files, filter, status_filter) do
    filter = filter |> String.trim() |> String.downcase()

    Enum.filter(files, fn file ->
      matches_filter = filter == "" or String.contains?(String.downcase(file.path), filter)
      matches_status = status_filter == "all" or Atom.to_string(file.status) == status_filter
      matches_filter and matches_status
    end)
  end

  defp directories(files) do
    files
    |> Enum.reduce(%{}, fn file, directories ->
      parts = Path.split(file.path)

      parts
      |> Enum.drop(-1)
      |> Enum.with_index()
      |> Enum.reduce(directories, fn {_part, index}, directories ->
        path = parts |> Enum.take(index + 1) |> Path.join()

        Map.update(
          directories,
          path,
          directory_entry(path, index, file.status),
          fn directory ->
            %{directory | changed: directory.changed + changed_count(file.status)}
          end
        )
      end)
    end)
    |> Map.values()
  end

  defp directory_entry(path, depth, status) do
    %{
      id: "dir:" <> path,
      path: path,
      name: Path.basename(path),
      kind: :directory,
      depth: depth,
      status: :directory,
      changed: changed_count(status)
    }
  end

  defp file_entry(file) do
    %{
      id: "file:" <> file.path,
      path: file.path,
      name: file.name,
      kind: :file,
      depth: max(length(Path.split(file.path)) - 1, 0),
      status: file.status,
      changed: changed_count(file.status)
    }
  end

  defp sort_key(entry), do: {Path.split(entry.path), kind_order(entry.kind)}
  defp kind_order(:directory), do: 0
  defp kind_order(:file), do: 1

  defp visible?(%{depth: 0}, _expanded), do: true

  defp visible?(entry, expanded) do
    entry.path
    |> Path.split()
    |> Enum.drop(-1)
    |> ancestors()
    |> Enum.all?(&MapSet.member?(expanded, &1))
  end

  defp ancestors(parts) do
    parts
    |> Enum.with_index()
    |> Enum.map(fn {_part, index} -> parts |> Enum.take(index + 1) |> Path.join() end)
  end

  defp annotate_accessibility(entries) do
    set_sizes = Enum.frequencies_by(entries, &parent_id/1)

    {entries, _positions} =
      Enum.map_reduce(entries, %{}, fn entry, positions ->
        parent_id = parent_id(entry)
        position = Map.get(positions, parent_id, 0) + 1

        entry =
          Map.merge(entry, %{
            parent_id: parent_id,
            level: entry.depth + 1,
            position: position,
            set_size: Map.fetch!(set_sizes, parent_id)
          })

        {entry, Map.put(positions, parent_id, position)}
      end)

    entries
  end

  defp parent_id(%{depth: 0}), do: nil
  defp parent_id(entry), do: "dir:" <> Path.dirname(entry.path)

  defp changed_count(:clean), do: 0
  defp changed_count(_status), do: 1
end

defmodule Examples.GitRepositoryBrowser.Model do
  @moduledoc false

  alias Examples.GitRepositoryBrowser.Tree

  def tree_slice(repository, expanded, filter, status_filter, range, selected_id) do
    entries = Tree.visible(repository.files, expanded, filter, status_filter)
    selected = Tree.selected_id(entries, selected_id)
    selected_index = Enum.find_index(entries, &(&1.id == selected))
    {offset, items} = loaded_slice(entries, range)

    %{
      total: length(entries),
      offset: offset,
      items: items,
      selected_index: selected_index
    }
  end

  def preview_slice(preview, range) do
    {offset, lines} = loaded_slice(preview.lines, range)
    %{total: length(preview.lines), offset: offset, lines: lines}
  end

  def repository_summary(repository), do: Map.drop(repository, [:files])
  def preview_summary(preview), do: Map.drop(preview, [:lines])

  def retain_selection(nil, _files), do: nil

  def retain_selection("file:" <> path = id, files) do
    if Enum.any?(files, &(&1.path == path)), do: id
  end

  def retain_selection("dir:" <> path = id, files) do
    prefix = path <> "/"
    if Enum.any?(files, &String.starts_with?(&1.path, prefix)), do: id
  end

  def initial_range, do: %{first: 0, last: 48}

  defp loaded_slice(items, %{first: first, last: last}) do
    count = length(items)
    first = first |> max(0) |> min(count)
    last = last |> max(first) |> min(count)
    {first, Enum.slice(items, first, last - first)}
  end
end

defmodule Examples.GitRepositoryBrowser.View do
  use GPUI.View

  alias Examples.GitRepositoryBrowser.Model
  alias GPUI.UI

  @impl GPUI.View
  def render(assigns) do
    selected =
      if is_integer(assigns.selected_index), do: assigns.selected_id

    ~GPUI"""
    <div class="flex flex-col w-[1200px] h-[760px] bg-slate-900">
      <div class="flex flex-col gap-3 p-4" style={[background: {:rgb, 0x1E293B}]}>
        <div class="flex items-center justify-between gap-4">
          <div class="flex flex-col gap-1">
            <text class="text-white text-2xl font-semibold">Git repository browser</text>
            <text style={[color: {:rgb, 0x94A3B8}]}>{repository_summary(assigns)}</text>
          </div>
          <UI.button
            id="refresh-repository"
            label={refresh_label(assigns.scan_status)}
            variant="primary"
            disabled={assigns.scan_status == :scanning}
            phx-click="reload_repository"
          />
        </div>
        <div class="flex gap-3">
          <UI.input
            id="repository-filter"
            value={assigns.filter}
            placeholder="Filter repository paths"
            cleanable={true}
            phx-change="filter_changed"
          />
          <UI.select
            id="status-filter"
            value={assigns.status_filter}
            options={status_options()}
            phx-change="status_filter_changed"
          />
        </div>
        {scan_status(assigns)}
      </div>

      <div class="flex h-[590px]">
        <div class="flex flex-col w-[430px] h-[590px]" style={[background: {:rgb, 0x0F172A}]}>
          <div class="flex items-center justify-between p-3">
            <text class="text-white font-semibold">Files</text>
            <text style={[color: {:rgb, 0x94A3B8}]}>{assigns.tree_total} visible</text>
          </div>
          <UI.tree
            id="repository-tree"
            label="Repository files"
            selected={selected}
            selected_index={assigns.selected_index}
            reveal={selected}
            reveal_index={assigns.selected_index}
            total_count={assigns.tree_total}
            offset={assigns.tree_offset}
            overscan={8}
            item_height={38}
            phx-change="tree_selected"
            phx-toggle="tree_toggled"
            phx-range="tree_range_changed"
            class="h-[540px]"
          >
            {Enum.map(assigns.tree_items, &tree_row(&1, assigns))}
          </UI.tree>
        </div>

        <div class="flex flex-col w-[770px] h-[590px]" style={[background: {:rgb, 0x111827}]}>
          {preview_panel(assigns)}
        </div>
      </div>
    </div>
    """
  end

  @impl GPUI.View
  def handle_event("filter_changed", %{value: filter}, assigns),
    do:
      {:noreply,
       %{
         assigns
         | filter: filter,
           tree_range: Model.initial_range(),
           tree_generation: assigns.tree_generation + 1
       }}

  def handle_event("status_filter_changed", %{value: status_filter}, assigns),
    do:
      {:noreply,
       %{
         assigns
         | status_filter: status_filter,
           tree_range: Model.initial_range(),
           tree_generation: assigns.tree_generation + 1
       }}

  def handle_event("tree_range_changed", %{value: range}, assigns),
    do: {:noreply, %{assigns | tree_range: range, tree_generation: assigns.tree_generation + 1}}

  def handle_event("preview_range_changed", %{value: range}, assigns),
    do:
      {:noreply,
       %{
         assigns
         | preview_range: range,
           preview_generation: assigns.preview_generation + 1
       }}

  def handle_event("reload_repository", _event, assigns) do
    {:noreply,
     %{
       assigns
       | scan_status: :scanning,
         scan_error: nil,
         scan_id: assigns.scan_id + 1
     }}
  end

  def handle_event("tree_selected", %{value: "dir:" <> _path = selected_id}, assigns) do
    {:noreply,
     %{
       assigns
       | selected_id: selected_id,
         selected_index: nil,
         tree_generation: assigns.tree_generation + 1
     }}
  end

  def handle_event("tree_toggled", %{value: "dir:" <> path}, assigns) do
    expanded =
      if MapSet.member?(assigns.expanded, path) do
        MapSet.delete(assigns.expanded, path)
      else
        MapSet.put(assigns.expanded, path)
      end

    {:noreply,
     %{
       assigns
       | expanded: expanded,
         tree_range: Model.initial_range(),
         tree_generation: assigns.tree_generation + 1
     }}
  end

  def handle_event("tree_selected", %{value: "file:" <> path = selected_id}, assigns) do
    {:noreply,
     %{
       assigns
       | selected_id: selected_id,
         selected_path: path,
         selected_index: nil,
         preview: nil,
         preview_lines: [],
         preview_total: 0,
         preview_offset: 0,
         preview_status: :loading,
         preview_error: nil,
         preview_job: assigns.preview_job + 1,
         preview_range: Model.initial_range(),
         preview_generation: assigns.preview_generation + 1
     }}
  end

  @impl GPUI.View
  def handle_info(
        {:repository_loaded, scan_id, repository, expanded, selected_id, selected_path, tree},
        %{scan_id: scan_id} = assigns
      ) do
    {:noreply,
     %{
       assigns
       | repository: repository,
         scan_status: :ready,
         scan_error: nil,
         expanded: expanded,
         tree_range: Model.initial_range(),
         tree_generation: assigns.tree_generation + 1,
         tree_total: tree.total,
         tree_offset: tree.offset,
         tree_items: tree.items,
         selected_id: selected_id,
         selected_path: selected_path,
         selected_index: tree.selected_index,
         preview: nil,
         preview_lines: [],
         preview_total: 0,
         preview_offset: 0,
         preview_status: if(selected_path, do: :loading, else: :idle),
         preview_job: if(selected_path, do: assigns.preview_job + 1, else: assigns.preview_job),
         preview_generation: assigns.preview_generation + 1
     }}
  end

  def handle_info({:repository_failed, scan_id, message}, %{scan_id: scan_id} = assigns),
    do: {:noreply, %{assigns | scan_status: :error, scan_error: message}}

  def handle_info(
        {:tree_slice, generation, tree},
        %{tree_generation: generation} = assigns
      ) do
    {:noreply,
     %{
       assigns
       | tree_total: tree.total,
         tree_offset: tree.offset,
         tree_items: tree.items,
         selected_index: tree.selected_index
     }}
  end

  def handle_info(
        {:preview_loaded, job_id, generation, preview, slice},
        %{preview_job: job_id} = assigns
      ) do
    assigns =
      %{
        assigns
        | preview: preview,
          preview_status: :ready,
          preview_error: nil
      }

    assigns =
      if assigns.preview_generation == generation do
        %{
          assigns
          | preview_lines: slice.lines,
            preview_total: slice.total,
            preview_offset: slice.offset
        }
      else
        assigns
      end

    {:noreply, assigns}
  end

  def handle_info(
        {:preview_slice, generation, slice},
        %{preview_generation: generation} = assigns
      ) do
    {:noreply,
     %{
       assigns
       | preview_lines: slice.lines,
         preview_total: slice.total,
         preview_offset: slice.offset
     }}
  end

  def handle_info({:preview_failed, job_id, message}, %{preview_job: job_id} = assigns),
    do: {:noreply, %{assigns | preview_status: :error, preview_error: message}}

  def handle_info(_message, assigns), do: {:noreply, assigns}

  defp tree_row(entry, assigns) do
    selected = entry.id == assigns.selected_id
    expanded = entry.kind == :directory and MapSet.member?(assigns.expanded, entry.path)
    row_assigns = %{entry: entry, selected: selected, expanded: expanded}

    ~GPUI"""
    <UI.tree_item
      id={row_assigns.entry.id}
      parent_id={row_assigns.entry.parent_id}
      level={row_assigns.entry.level}
      branch={row_assigns.entry.kind == :directory}
      expanded={row_assigns.expanded}
      position={row_assigns.entry.position}
      set_size={row_assigns.entry.set_size}
      style={tree_row_style(row_assigns.selected)}
    >
      <div class="flex items-center gap-2 p-2">
        <div style={[width: {:px, row_assigns.entry.depth * 16}, height: {:px, 1}]} />
        <text class="text-white w-[18px]">{entry_marker(row_assigns.entry, row_assigns.expanded)}</text>
        <text class="text-white w-[245px]">{row_assigns.entry.name}</text>
        <text style={[color: status_color(row_assigns.entry.status)]}>{status_label(row_assigns.entry)}</text>
      </div>
    </UI.tree_item>
    """
  end

  defp preview_panel(%{preview_status: :loading} = assigns) do
    ~GPUI"""
    <div class="flex flex-col gap-4 p-5">
      <text class="text-white text-xl font-semibold">{assigns.selected_path}</text>
      <UI.progress id="preview-progress" label="Loading file preview" indeterminate={true} />
    </div>
    """
  end

  defp preview_panel(%{preview_status: :error} = assigns) do
    ~GPUI"""
    <div class="flex flex-col gap-3 p-5">
      <text class="text-white text-xl font-semibold">Unable to preview file</text>
      <text style={[color: {:rgb, 0xFCA5A5}]}>{assigns.preview_error}</text>
    </div>
    """
  end

  defp preview_panel(%{preview: nil}) do
    ~GPUI"""
    <div class="flex flex-col gap-3 p-5">
      <text class="text-white text-xl font-semibold">File preview</text>
      <text style={[color: {:rgb, 0x94A3B8}]}>Select a file to inspect its content or working-tree diff.</text>
    </div>
    """
  end

  defp preview_panel(assigns) do
    ~GPUI"""
    <div class="flex flex-col h-[590px]">
      <div class="flex items-center justify-between p-3">
        <text class="text-white text-lg font-semibold">{assigns.preview.path}</text>
        <text style={[color: status_color(assigns.preview.status)]}>{preview_label(assigns.preview)}</text>
      </div>
      <UI.virtual_list
        id="preview-lines"
        label="File preview lines"
        total_count={assigns.preview_total}
        offset={assigns.preview_offset}
        overscan={12}
        item_height={24}
        phx-range="preview_range_changed"
        class="h-[540px]"
      >
        {Enum.map(assigns.preview_lines, &preview_line/1)}
      </UI.virtual_list>
    </div>
    """
  end

  defp preview_line(line) do
    assigns = %{line: line}

    ~GPUI"""
    <UI.virtual_list_item id={assigns.line.id}>
      <div class="flex items-center" style={[background: line_background(assigns.line.kind)]}>
        <text class="w-[58px]" style={[color: {:rgb, 0x64748B}]}>{line_number(assigns.line.number)}</text>
        <text style={[color: line_color(assigns.line.kind)]}>{assigns.line.text}</text>
      </div>
    </UI.virtual_list_item>
    """
  end

  defp scan_status(%{scan_status: :scanning}) do
    ~GPUI"""
    <UI.progress id="repository-scan" label="Scanning repository" indeterminate={true} class="w-[520px]" />
    """
  end

  defp scan_status(%{scan_status: :error} = assigns) do
    ~GPUI"""
    <text style={[color: {:rgb, 0xFCA5A5}]}>{assigns.scan_error}</text>
    """
  end

  defp scan_status(_assigns) do
    ~GPUI"""
    <div />
    """
  end

  defp repository_summary(%{repository: nil}), do: "Waiting for a server-local repository scan"

  defp repository_summary(assigns) do
    repository = assigns.repository

    "#{repository.root} · #{repository.branch} · #{repository.counts.total} files · " <>
      "#{repository.counts.changed} changed"
  end

  defp refresh_label(:scanning), do: "Scanning…"
  defp refresh_label(_status), do: "Refresh"

  defp entry_marker(%{kind: :file}, _expanded), do: "·"
  defp entry_marker(%{kind: :directory}, true), do: "▾"
  defp entry_marker(%{kind: :directory}, false), do: "▸"

  defp status_label(%{kind: :directory, changed: 0}), do: ""
  defp status_label(%{kind: :directory, changed: changed}), do: "#{changed} changed"
  defp status_label(%{status: :clean}), do: ""
  defp status_label(entry), do: entry.status |> Atom.to_string() |> String.upcase()

  defp preview_label(%{mode: :diff, status: status}), do: "#{status} diff"
  defp preview_label(%{mode: :file}), do: "file content"
  defp preview_label(%{mode: :notice}), do: "preview notice"

  defp status_color(:clean), do: {:rgb, 0x64748B}
  defp status_color(:directory), do: {:rgb, 0x94A3B8}
  defp status_color(:modified), do: {:rgb, 0xFBBF24}
  defp status_color(:added), do: {:rgb, 0x86EFAC}
  defp status_color(:untracked), do: {:rgb, 0x67E8F9}
  defp status_color(:renamed), do: {:rgb, 0xC4B5FD}
  defp status_color(:deleted), do: {:rgb, 0xFCA5A5}

  defp tree_row_style(true), do: [background: {:rgb, 0x1D4ED8}]
  defp tree_row_style(false), do: [background: {:rgb, 0x0F172A}]

  defp line_background(:added), do: {:rgb, 0x123524}
  defp line_background(:deleted), do: {:rgb, 0x3F1D24}
  defp line_background(:hunk), do: {:rgb, 0x1E3A5F}
  defp line_background(_kind), do: {:rgb, 0x111827}

  defp line_color(:added), do: {:rgb, 0xBBF7D0}
  defp line_color(:deleted), do: {:rgb, 0xFECACA}
  defp line_color(:hunk), do: {:rgb, 0xBFDBFE}
  defp line_color(:header), do: {:rgb, 0xC4B5FD}
  defp line_color(:notice), do: {:rgb, 0xFDE68A}
  defp line_color(_kind), do: {:rgb, 0xE2E8F0}

  defp line_number(nil), do: ""
  defp line_number(number), do: Integer.to_string(number)

  defp status_options do
    [
      {"All files", "all"},
      {"Modified", "modified"},
      {"Added", "added"},
      {"Deleted", "deleted"},
      {"Renamed", "renamed"},
      {"Untracked", "untracked"},
      {"Clean", "clean"}
    ]
  end
end

defmodule Examples.GitRepositoryBrowser.App do
  use GPUI.Application

  alias Examples.GitRepositoryBrowser.Model
  alias Examples.GitRepositoryBrowser.Tree

  @impl GPUI.Application
  def mount(args) do
    args = Map.new(args)
    repository = Map.get(args, :repository)
    files = if repository, do: repository.files, else: []
    selected_path = Map.get(args, :selected_path)
    selected_id = if selected_path, do: "file:" <> selected_path
    preview = Map.get(args, :preview)
    expanded = Map.get_lazy(args, :expanded, fn -> Tree.default_expanded(files) end)
    range = Model.initial_range()

    tree =
      if repository do
        Model.tree_slice(repository, expanded, "", "all", range, selected_id)
      else
        %{total: 0, offset: 0, items: [], selected_index: nil}
      end

    preview_slice =
      if preview, do: Model.preview_slice(preview, range), else: %{total: 0, offset: 0, lines: []}

    {:ok,
     [
       window "Git Repository Browser" do
         size(1200, 760)

         root(Examples.GitRepositoryBrowser.View,
           path: Map.get(args, :path, File.cwd!()),
           repository: if(repository, do: Model.repository_summary(repository)),
           scan_status: if(repository, do: :ready, else: :scanning),
           scan_error: nil,
           scan_id: 1,
           expanded: expanded,
           selected_id: selected_id,
           selected_path: selected_path,
           selected_index: tree.selected_index,
           tree_items: tree.items,
           tree_total: tree.total,
           tree_offset: tree.offset,
           tree_range: range,
           tree_generation: 0,
           preview: if(preview, do: Model.preview_summary(preview)),
           preview_lines: preview_slice.lines,
           preview_total: preview_slice.total,
           preview_offset: preview_slice.offset,
           preview_status: if(preview, do: :ready, else: :idle),
           preview_error: nil,
           preview_job: 0,
           preview_range: range,
           preview_generation: 0,
           filter: "",
           status_filter: "all"
         )
       end
     ]}
  end
end

defmodule Examples.GitRepositoryBrowser.Coordinator do
  use GenServer

  alias Examples.GitRepositoryBrowser.Model
  alias Examples.GitRepositoryBrowser.Repository
  alias Examples.GitRepositoryBrowser.Tree
  alias GPUI.Runtime
  alias GPUI.Runtime.Update

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @impl GenServer
  def init(opts) do
    runtime = Keyword.fetch!(opts, :runtime)
    :ok = Runtime.subscribe(runtime)

    state = %{
      runtime: runtime,
      path: Keyword.fetch!(opts, :path),
      task_supervisor: Keyword.fetch!(opts, :task_supervisor),
      repository_module: Keyword.get(opts, :repository_module, Repository),
      repository_opts: Keyword.get(opts, :repository_opts, []),
      owner: Keyword.get(opts, :owner),
      scan_task: nil,
      preview_task: nil,
      repository: nil,
      preview: nil
    }

    send(self(), :initial_scan)
    {:ok, state}
  end

  @impl GenServer
  def handle_info(:initial_scan, state), do: {:noreply, start_scan(state, 1)}

  def handle_info({:gpui, runtime, %Update{} = update}, %{runtime: runtime} = state) do
    assigns = root_assigns(update.snapshot)

    state =
      Enum.reduce(update.events, state, fn
        %{event: "reload_repository"}, state ->
          start_scan(state, assigns.scan_id)

        %{event: "tree_selected", value: "file:" <> path}, state ->
          state
          |> publish_tree(assigns)
          |> start_preview(assigns.preview_job, path)

        %{event: event}, state
        when event in [
               "filter_changed",
               "status_filter_changed",
               "tree_range_changed",
               "tree_selected",
               "tree_toggled"
             ] ->
          publish_tree(state, assigns)

        %{event: "preview_range_changed"}, state ->
          publish_preview(state, assigns)

        _event, state ->
          state
      end)

    {:noreply, state}
  end

  def handle_info({:scan_complete, scan_id, {:ok, repository}}, state) do
    if active_job?(state.scan_task, scan_id) do
      assigns = state.runtime |> Runtime.snapshot() |> root_assigns()
      selected_id = Model.retain_selection(assigns.selected_id, repository.files)

      selected_path =
        if selected_id && String.starts_with?(selected_id, "file:"),
          do: String.replace_prefix(selected_id, "file:", "")

      expanded = Tree.default_expanded(repository.files)

      tree =
        Model.tree_slice(
          repository,
          expanded,
          assigns.filter,
          assigns.status_filter,
          Model.initial_range(),
          selected_id
        )

      {:ok, snapshot} =
        Runtime.send_view(
          state.runtime,
          1,
          {:repository_loaded, scan_id, Model.repository_summary(repository), expanded,
           selected_id, selected_path, tree}
        )

      state = %{
        state
        | repository: repository,
          preview: nil,
          scan_task: finish_task(state.scan_task)
      }

      updated_assigns = root_assigns(snapshot)

      state =
        if updated_assigns.selected_path do
          start_preview(state, updated_assigns.preview_job, updated_assigns.selected_path)
        else
          state
        end

      notify(state.owner, {:git_repository_browser, :loaded, scan_id})
      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  def handle_info({:scan_complete, scan_id, {:error, message}}, state) do
    if active_job?(state.scan_task, scan_id) do
      {:ok, _snapshot} =
        Runtime.send_view(state.runtime, 1, {:repository_failed, scan_id, message})

      notify(state.owner, {:git_repository_browser, :scan_failed, scan_id, message})
      {:noreply, %{state | scan_task: finish_task(state.scan_task)}}
    else
      {:noreply, state}
    end
  end

  def handle_info({:preview_complete, job_id, {:ok, preview}}, state) do
    if active_job?(state.preview_task, job_id) do
      assigns = state.runtime |> Runtime.snapshot() |> root_assigns()
      slice = Model.preview_slice(preview, assigns.preview_range)

      {:ok, _snapshot} =
        Runtime.send_view(
          state.runtime,
          1,
          {:preview_loaded, job_id, assigns.preview_generation, Model.preview_summary(preview),
           slice}
        )

      notify(state.owner, {:git_repository_browser, :previewed, job_id})

      {:noreply,
       %{
         state
         | preview: preview,
           preview_task: finish_task(state.preview_task)
       }}
    else
      {:noreply, state}
    end
  end

  def handle_info({:preview_complete, job_id, {:error, message}}, state) do
    if active_job?(state.preview_task, job_id) do
      {:ok, _snapshot} = Runtime.send_view(state.runtime, 1, {:preview_failed, job_id, message})
      notify(state.owner, {:git_repository_browser, :preview_failed, job_id, message})
      {:noreply, %{state | preview: nil, preview_task: finish_task(state.preview_task)}}
    else
      {:noreply, state}
    end
  end

  def handle_info({ref, _result}, state) when is_reference(ref), do: {:noreply, state}

  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    cond do
      task_ref(state.scan_task) == ref ->
        maybe_report_task_exit(state.owner, :scan, reason)
        {:noreply, %{state | scan_task: nil}}

      task_ref(state.preview_task) == ref ->
        maybe_report_task_exit(state.owner, :preview, reason)
        {:noreply, %{state | preview_task: nil}}

      true ->
        {:noreply, state}
    end
  end

  defp publish_tree(%{repository: nil} = state, _assigns), do: state

  defp publish_tree(state, assigns) do
    tree =
      Model.tree_slice(
        state.repository,
        assigns.expanded,
        assigns.filter,
        assigns.status_filter,
        assigns.tree_range,
        assigns.selected_id
      )

    {:ok, _snapshot} =
      Runtime.send_view(
        state.runtime,
        1,
        {:tree_slice, assigns.tree_generation, tree}
      )

    notify(state.owner, {:git_repository_browser, :tree_slice, assigns.tree_generation})
    state
  end

  defp publish_preview(%{preview: nil} = state, _assigns), do: state

  defp publish_preview(state, assigns) do
    slice = Model.preview_slice(state.preview, assigns.preview_range)

    {:ok, _snapshot} =
      Runtime.send_view(
        state.runtime,
        1,
        {:preview_slice, assigns.preview_generation, slice}
      )

    notify(state.owner, {:git_repository_browser, :preview_slice, assigns.preview_generation})
    state
  end

  defp start_scan(state, scan_id) do
    state = %{
      state
      | scan_task: cancel_task(state.scan_task),
        preview_task: cancel_task(state.preview_task)
    }

    parent = self()
    repository_module = state.repository_module
    repository_opts = state.repository_opts
    path = state.path

    task =
      Task.Supervisor.async_nolink(state.task_supervisor, fn ->
        result = repository_module.scan(path, repository_opts)
        send(parent, {:scan_complete, scan_id, result})
      end)

    %{state | scan_task: %{task: task, job_id: scan_id}}
  end

  defp start_preview(%{repository: nil} = state, _job_id, _path), do: state

  defp start_preview(state, job_id, path) do
    state = %{state | preview: nil, preview_task: cancel_task(state.preview_task)}
    parent = self()
    repository_module = state.repository_module
    repository_opts = state.repository_opts
    repository = state.repository

    task =
      Task.Supervisor.async_nolink(state.task_supervisor, fn ->
        result = repository_module.preview(repository, path, repository_opts)
        send(parent, {:preview_complete, job_id, result})
      end)

    %{state | preview_task: %{task: task, job_id: job_id}}
  end

  defp root_assigns(%GPUI.Snapshot{windows: [%{root: %{assigns: assigns}} | _windows]}),
    do: assigns

  defp active_job?(%{job_id: job_id}, job_id), do: true
  defp active_job?(_task, _job_id), do: false
  defp task_ref(%{task: %Task{ref: ref}}), do: ref
  defp task_ref(_task), do: nil

  defp finish_task(%{task: %Task{ref: ref}}) do
    Process.demonitor(ref, [:flush])
    nil
  end

  defp cancel_task(nil), do: nil

  defp cancel_task(%{task: task}) do
    _result = Task.shutdown(task, :brutal_kill)
    nil
  end

  defp maybe_report_task_exit(_owner, _kind, :normal), do: :ok

  defp maybe_report_task_exit(owner, kind, reason),
    do: notify(owner, {:git_repository_browser, :task_exit, kind, reason})

  defp notify(nil, _message), do: :ok
  defp notify(owner, message), do: send(owner, message)
end

defmodule Examples.GitRepositoryBrowser.Supervisor do
  use Supervisor

  def start_link(opts), do: Supervisor.start_link(__MODULE__, opts)

  @impl Supervisor
  def init(opts) do
    task_supervisor =
      Keyword.get(opts, :task_supervisor, Examples.GitRepositoryBrowser.TaskSupervisor)

    coordinator_opts =
      opts
      |> Keyword.put(:task_supervisor, task_supervisor)
      |> Keyword.delete(:name)

    children = [
      {Task.Supervisor, name: task_supervisor},
      {Examples.GitRepositoryBrowser.Coordinator, coordinator_opts}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
