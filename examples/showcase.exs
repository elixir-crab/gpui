# Run with:
#   mix run examples/showcase.exs
#
# Exercise events without a native display:
#   GPUI_SHOWCASE_BACKEND=data mix run examples/showcase.exs

defmodule ShowcaseView do
  use GPUI.View

  @impl GPUI.View
  def render(assigns) do
    active_task = Enum.find(assigns.tasks, &(&1.id == assigns.selected_task))
    theme = theme(assigns.theme)

    ~GPUI"""
    <div class={"flex flex-col bg-#{theme.bg} text-white p-6 gap-4"}>
      <div class="flex flex-col gap-2">
        <text class="text-3xl">GPUI + Elixir Showcase</text>
        <text class="text-sm">Stateful views, event routing, dynamic styles, inputs, and nested layouts.</text>
      </div>

      <div class="flex flex-row gap-4">
        <div class="flex flex-col bg-slate-800 p-4 gap-3 rounded-lg w-[260px]">
          <text class="text-xl">Counter</text>
          <text class="text-3xl">{assigns.count}</text>
          <div class="flex flex-row gap-2">
            <button phx-click="dec" class="bg-slate-700 text-white p-2 rounded-md">−</button>
            <button phx-click="inc" class="bg-blue-600 text-white p-2 rounded-md">+</button>
            <button phx-click="reset" class="bg-red-600 text-white p-2 rounded-md">Reset</button>
          </div>
        </div>

        <div class="flex flex-col bg-slate-800 p-4 gap-3 rounded-lg w-[320px]">
          <text class="text-xl">Session</text>
          <input value={assigns.name} placeholder="Type a label" phx-change="rename" class="bg-slate-700 text-white p-2 rounded-md" />
          <text class="text-sm">Active label: {assigns.name}</text>
          <button phx-click="toggle_theme" class={"bg-#{theme.button} text-white p-2 rounded-md"}>
            Toggle theme
          </button>
        </div>
      </div>

      <div class="flex flex-row gap-4">
        <div class="flex flex-col bg-slate-800 p-4 gap-2 rounded-lg w-[260px]">
          <text class="text-xl">Task picker</text>
          <button phx-click="select_dashboard" class={task_class(assigns.selected_task, :dashboard)}>Dashboard</button>
          <button phx-click="select_editor" class={task_class(assigns.selected_task, :editor)}>Editor</button>
          <button phx-click="select_remote" class={task_class(assigns.selected_task, :remote)}>Remote app</button>
        </div>

        <div class="flex flex-col bg-slate-800 p-4 gap-3 rounded-lg w-[420px]">
          <text class="text-xl">Details</text>
          <text class="text-2xl">{active_task.title}</text>
          <text class="text-base">{active_task.description}</text>
          <text class="text-sm">Selected: {active_task.id}</text>
        </div>
      </div>
    </div>
    """
  end

  @impl GPUI.View
  def handle_event("inc", _event, assigns), do: {:noreply, %{assigns | count: assigns.count + 1}}
  def handle_event("dec", _event, assigns), do: {:noreply, %{assigns | count: assigns.count - 1}}
  def handle_event("reset", _event, assigns), do: {:noreply, %{assigns | count: 0}}

  def handle_event("rename", %{value: value}, assigns) do
    {:noreply, %{assigns | name: value}}
  end

  def handle_event("toggle_theme", _event, %{theme: :dark} = assigns) do
    {:noreply, %{assigns | theme: :blue}}
  end

  def handle_event("toggle_theme", _event, assigns) do
    {:noreply, %{assigns | theme: :dark}}
  end

  def handle_event("select_dashboard", _event, assigns) do
    {:noreply, %{assigns | selected_task: :dashboard}}
  end

  def handle_event("select_editor", _event, assigns) do
    {:noreply, %{assigns | selected_task: :editor}}
  end

  def handle_event("select_remote", _event, assigns) do
    {:noreply, %{assigns | selected_task: :remote}}
  end

  defp theme(:blue), do: %{bg: "blue-700", button: "slate-700"}
  defp theme(_theme), do: %{bg: "slate-900", button: "blue-600"}

  defp task_class(selected, id) when selected == id,
    do: "bg-blue-600 text-white p-2 rounded-md"

  defp task_class(_selected, _id),
    do: "bg-slate-700 text-white p-2 rounded-md"
end

defmodule ShowcaseApp do
  use GPUI.Application

  @impl GPUI.Application
  def mount(_args) do
    {:ok, %{},
     [
       window "GPUI Showcase" do
         size(900, 640)
         root(ShowcaseView, initial_assigns())
       end
     ]}
  end

  defp initial_assigns do
    %{
      count: 3,
      name: "Elixir runtime",
      theme: :dark,
      selected_task: :dashboard,
      tasks: [
        %{
          id: :dashboard,
          title: "Dashboard",
          description: "Composable cards driven by serializable Elixir data."
        },
        %{
          id: :editor,
          title: "Editor",
          description: "Inputs and events update assigns through GPUI.Runtime."
        },
        %{
          id: :remote,
          title: "Remote app",
          description: "The same view tree can be transported to remote display backends."
        }
      ]
    }
  end
end

unless System.get_env("GPUI_SHOWCASE_NO_RUN") == "1" do
  backend =
    case System.get_env("GPUI_SHOWCASE_BACKEND", "data") do
      "native" -> :native
      "host" -> :host
      "remote_tcp" -> :remote_tcp
      _other -> :data
    end

  children = [
    {ShowcaseApp, backend: backend, poll_interval: 16}
  ]

  {:ok, _supervisor} = Supervisor.start_link(children, strategy: :one_for_one)

  IO.puts("GPUI showcase running with backend=#{backend}. Press Ctrl+C twice to exit.")
  Process.sleep(:infinity)
end
