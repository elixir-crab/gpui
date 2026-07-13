defmodule GPUI.RuntimeTest do
  use ExUnit.Case, async: true

  defmodule HelloView do
    use GPUI.View

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div class="flex flex-col items-center bg-neutral-700">
        <text>Hello {assigns.name}</text>
      </div>
      """
    end
  end

  defmodule DemoApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(_args) do
      {:ok,
       [
         window "GPUI + Elixir" do
           size(500, 500)
           root(HelloView, name: "OTP")
         end
       ]}
    end
  end

  defmodule EmptyApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(_args), do: {:ok, []}
  end

  test "application modules start renderer-independent sessions with a display" do
    {:ok, runtime} =
      start_supervised({DemoApp, display: GPUITest.Display, display_opts: [owner: self()]})

    assert [%GPUI.WindowSpec{title: "GPUI + Elixir", size: {500, 500}}] =
             GPUI.Runtime.windows(runtime)

    assert_receive {:display_snapshot, %{windows: [%{id: 1}]}}
  end

  test "runtime snapshots contain rendered window trees" do
    {:ok, runtime} =
      GPUI.Runtime.start_link(app: DemoApp, display: GPUITest.Display)

    assert %{
             windows: [
               %{
                 root: %{
                   module: module,
                   assigns: %{name: "OTP"},
                   tree: %{
                     type: :div,
                     attrs: %{
                       style: [
                         display: :flex,
                         flex_direction: :column,
                         align_items: :center,
                         background: [:rgb, 4_210_752]
                       ]
                     },
                     children: [%{type: :text, children: ["Hello ", "OTP"]}]
                   }
                 }
               }
             ],
             resources: %{}
           } = GPUI.Runtime.snapshot(runtime)

    assert module =~ "HelloView"
  end

  test "applications can mount an empty window set without placeholder state" do
    {:ok, session} = GPUI.Session.start_link(app: EmptyApp)

    assert [] = GPUI.Session.windows(session)
    assert %GPUI.Snapshot{windows: [], resources: %{}} = GPUI.Session.snapshot(session)
  end

  test "sessions can run without any display" do
    {:ok, session} = GPUI.Session.start_link(app: DemoApp)

    assert [%GPUI.WindowSpec{title: "GPUI + Elixir"}] = GPUI.Session.windows(session)
    assert %{windows: [%{id: 1}], resources: %{}} = GPUI.Session.snapshot(session)
  end
end
