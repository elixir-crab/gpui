defmodule GPUI.ApplicationChildSpecTest do
  use ExUnit.Case, async: true

  defmodule Application do
    use GPUI.Application

    @impl GPUI.Application
    def mount(_args), do: {:ok, []}

    def child_spec(opts) do
      super(opts)
      |> Map.put(:restart, :transient)
    end
  end

  test "application modules can refine the generated child specification" do
    assert %{restart: :transient, start: {GPUI.Runtime, :start_link, [opts]}} =
             Application.child_spec(name: __MODULE__.Runtime)

    assert opts[:app] == Application
  end
end
