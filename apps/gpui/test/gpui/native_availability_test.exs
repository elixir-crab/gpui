defmodule GPUI.NativeAvailabilityTest do
  use ExUnit.Case, async: true

  test "native-backed operations fail cleanly when the backend is absent" do
    previous = Application.get_env(:gpui, :native_backend)
    Application.put_env(:gpui, :native_backend, __MODULE__.MissingBackend)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:gpui, :native_backend, previous),
        else: Application.delete_env(:gpui, :native_backend)
    end)

    refute GPUI.Native.available?()
    assert {:error, :native_backend_unavailable} = GPUI.Text.Buffer.new("text")
  end
end
