defmodule GPUI.TailwindPolicyTest do
  use ExUnit.Case, async: false

  test "strict policy rejects unsupported classes during serialization" do
    previous = Application.get_env(:gpui, :unknown_classes)
    Application.put_env(:gpui, :unknown_classes, :error)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:gpui, :unknown_classes, previous),
        else: Application.delete_env(:gpui, :unknown_classes)
    end)

    assert_raise ArgumentError, ~r/unsupported GPUI classes: misspelled-class/, fn ->
      GPUI.Element.to_payload(%GPUI.Element{type: :div, attrs: [class: "misspelled-class"]})
    end
  end
end
