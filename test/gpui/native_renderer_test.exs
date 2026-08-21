defmodule GPUI.Test.NativeTest do
  use GPUI.Test, async: false

  @moduletag :native

  defmodule FormView do
    use GPUI.View

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div class="flex flex-col w-[320px] h-[120px] gap-4">
        <GPUI.UI.radio_group
          id="plan"
          label="Plan"
          value={assigns.plan}
          options={[
            %{label: "Free", value: "free"},
            %{label: "Pro", value: "pro", disabled: true},
            %{label: "Team", value: "team"}
          ]}
          orientation="horizontal"
          phx-change="plan_changed"
        />
      </div>
      """
    end
  end

  test "drives the native renderer from ExUnit through stable IDs" do
    test = GPUI.Test.Native.start!(width: 320, height: 120)
    on_exit(fn -> GPUI.Test.Native.stop(test) end)

    test
    |> GPUI.Test.Native.render_view!(FormView, plan: "free")
    |> GPUI.Test.Native.focus!("plan")
    |> GPUI.Test.Native.key!("right")

    assert [%{type: :change, event: "plan_changed", value: "team"}] =
             GPUI.Test.Native.events!(test)
  end
end
