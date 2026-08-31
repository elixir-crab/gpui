defmodule Examples.PipelineMonitor.Fixtures do
  @moduledoc false

  @kinds [:success, :slow_success, :fail_once, :permanent_failure]

  def kinds, do: @kinds

  def outcome(:success, _attempt), do: {:ok, 24}
  def outcome(:slow_success, _attempt), do: {:ok, 180}
  def outcome(:fail_once, 1), do: {:error, "upstream timeout", 72}
  def outcome(:fail_once, _attempt), do: {:ok, 48}
  def outcome(:permanent_failure, _attempt), do: {:error, "invalid payload", 36}
end
