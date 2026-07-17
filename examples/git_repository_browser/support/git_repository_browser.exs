Code.require_file("repository.exs", __DIR__)

defmodule Examples.GitRepositoryBrowser.Tree do
  @moduledoc false

  def visible(files, expanded, filter, status_filter) do
    files = filter_files(files, filter, status_filter)
    directories = directories(files)

    (directories ++ Enum.map(files, &file_entry/1))
    |> Enum.sort_by(&sort_key/1)
    |> Enum.filter(&visible?(&1, expanded))
  end

  def default_expanded(files) do
    files
    |> directories()
    |> Enum.filter(&(&1.depth == 0))
    |> Enum.map(& &1.path)
    |> MapSet.new()
  end

  def selected_id(entries, selected_path) do
    id = if selected_path, do: "file:" <> selected_path
    if Enum.any?(entries, &(&1.id == id)), do: id
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

  defp changed_count(:clean), do: 0
  defp changed_count(_status), do: 1
end

defmodule Examples.GitRepositoryBrowser.View do
  use GPUI.View

  alias Examples.GitRepositoryBrowser.Tree
  alias GPUI.UI

  @impl GPUI.View
  def render(assigns) do
    files = if assigns.repository, do: assigns.repository.files, else: []
    entries = Tree.visible(files, assigns.expanded, assigns.filter, assigns.status_filter)
    selected = Tree.selected_id(entries, assigns.selected_path)

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
            <text style={[color: {:rgb, 0x94A3B8}]}>{length(entries)} visible</text>
          </div>
          <UI.virtual_list
            id="repository-tree"
            label="Repository files"
            selected={selected}
            reveal={selected}
            item_height={38}
            phx-change="tree_selected"
            class="h-[540px]"
          >
            {Enum.map(entries, &tree_row(&1, assigns))}
          </UI.virtual_list>
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
    do: {:noreply, %{assigns | filter: filter}}

  def handle_event("status_filter_changed", %{value: status_filter}, assigns),
    do: {:noreply, %{assigns | status_filter: status_filter}}

  def handle_event("reload_repository", _event, assigns) do
    {:noreply,
     %{
       assigns
       | scan_status: :scanning,
         scan_error: nil,
         scan_id: assigns.scan_id + 1
     }}
  end

  def handle_event("tree_selected", %{value: "dir:" <> path}, assigns) do
    expanded =
      if MapSet.member?(assigns.expanded, path) do
        MapSet.delete(assigns.expanded, path)
      else
        MapSet.put(assigns.expanded, path)
      end

    {:noreply, %{assigns | expanded: expanded}}
  end

  def handle_event("tree_selected", %{value: "file:" <> path}, assigns) do
    {:noreply,
     %{
       assigns
       | selected_path: path,
         preview: nil,
         preview_status: :loading,
         preview_error: nil,
         preview_job: assigns.preview_job + 1
     }}
  end

  @impl GPUI.View
  def handle_info({:repository_loaded, scan_id, repository}, %{scan_id: scan_id} = assigns) do
    selected_path = retain_selection(assigns.selected_path, repository.files)

    {:noreply,
     %{
       assigns
       | repository: repository,
         scan_status: :ready,
         scan_error: nil,
         expanded: Tree.default_expanded(repository.files),
         selected_path: selected_path,
         preview: nil,
         preview_status: if(selected_path, do: :loading, else: :idle),
         preview_job: if(selected_path, do: assigns.preview_job + 1, else: assigns.preview_job)
     }}
  end

  def handle_info({:repository_failed, scan_id, message}, %{scan_id: scan_id} = assigns),
    do: {:noreply, %{assigns | scan_status: :error, scan_error: message}}

  def handle_info({:preview_loaded, job_id, preview}, %{preview_job: job_id} = assigns),
    do: {:noreply, %{assigns | preview: preview, preview_status: :ready, preview_error: nil}}

  def handle_info({:preview_failed, job_id, message}, %{preview_job: job_id} = assigns),
    do: {:noreply, %{assigns | preview_status: :error, preview_error: message}}

  def handle_info(_message, assigns), do: {:noreply, assigns}

  defp tree_row(entry, assigns) do
    selected = entry.kind == :file and entry.path == assigns.selected_path
    expanded = entry.kind == :directory and MapSet.member?(assigns.expanded, entry.path)
    row_assigns = %{entry: entry, selected: selected, expanded: expanded}

    ~GPUI"""
    <UI.virtual_list_item id={row_assigns.entry.id} style={tree_row_style(row_assigns.selected)}>
      <div class="flex items-center gap-2 p-2">
        <div style={[width: {:px, row_assigns.entry.depth * 16}, height: {:px, 1}]} />
        <text class="text-white w-[18px]">{entry_marker(row_assigns.entry, row_assigns.expanded)}</text>
        <text class="text-white w-[245px]">{row_assigns.entry.name}</text>
        <text style={[color: status_color(row_assigns.entry.status)]}>{status_label(row_assigns.entry)}</text>
      </div>
    </UI.virtual_list_item>
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
        item_height={24}
        class="h-[540px]"
      >
        {Enum.map(assigns.preview.lines, &preview_line/1)}
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

  defp retain_selection(nil, _files), do: nil

  defp retain_selection(path, files) do
    if Enum.any?(files, &(&1.path == path)), do: path
  end

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

  alias Examples.GitRepositoryBrowser.Tree

  @impl GPUI.Application
  def mount(args) do
    args = Map.new(args)
    repository = Map.get(args, :repository)
    files = if repository, do: repository.files, else: []
    selected_path = Map.get(args, :selected_path)
    preview = Map.get(args, :preview)

    {:ok,
     [
       window "Git Repository Browser" do
         size(1200, 760)

         root(Examples.GitRepositoryBrowser.View,
           path: Map.get(args, :path, File.cwd!()),
           repository: repository,
           scan_status: if(repository, do: :ready, else: :scanning),
           scan_error: nil,
           scan_id: 1,
           expanded: Map.get_lazy(args, :expanded, fn -> Tree.default_expanded(files) end),
           selected_path: selected_path,
           preview: preview,
           preview_status: if(preview, do: :ready, else: :idle),
           preview_error: nil,
           preview_job: 0,
           filter: "",
           status_filter: "all"
         )
       end
     ]}
  end
end

defmodule Examples.GitRepositoryBrowser.Coordinator do
  use GenServer

  alias Examples.GitRepositoryBrowser.Repository
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
      repository: nil
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
          start_preview(state, assigns.preview_job, path)

        _event, state ->
          state
      end)

    {:noreply, state}
  end

  def handle_info({:scan_complete, scan_id, {:ok, repository}}, state) do
    if active_job?(state.scan_task, scan_id) do
      {:ok, snapshot} =
        Runtime.send_view(state.runtime, 1, {:repository_loaded, scan_id, repository})

      state = %{state | repository: repository, scan_task: finish_task(state.scan_task)}
      assigns = root_assigns(snapshot)

      state =
        if assigns.selected_path do
          start_preview(state, assigns.preview_job, assigns.selected_path)
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
      {:ok, _snapshot} = Runtime.send_view(state.runtime, 1, {:preview_loaded, job_id, preview})
      notify(state.owner, {:git_repository_browser, :previewed, job_id})
      {:noreply, %{state | preview_task: finish_task(state.preview_task)}}
    else
      {:noreply, state}
    end
  end

  def handle_info({:preview_complete, job_id, {:error, message}}, state) do
    if active_job?(state.preview_task, job_id) do
      {:ok, _snapshot} = Runtime.send_view(state.runtime, 1, {:preview_failed, job_id, message})
      notify(state.owner, {:git_repository_browser, :preview_failed, job_id, message})
      {:noreply, %{state | preview_task: finish_task(state.preview_task)}}
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
    state = %{state | preview_task: cancel_task(state.preview_task)}
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
