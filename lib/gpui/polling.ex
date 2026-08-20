defmodule GPUI.Polling do
  @moduledoc "Validation for optional runtime and remote display polling intervals."

  @spec interval(keyword(), pos_integer()) ::
          {:ok, pos_integer() | nil} | {:error, {:invalid_option, :poll_interval}}
  def interval(opts, default \\ 16) do
    case Keyword.get(opts, :poll_interval, default) do
      nil -> {:ok, nil}
      interval when is_integer(interval) and interval > 0 -> {:ok, interval}
      _invalid -> {:error, {:invalid_option, :poll_interval}}
    end
  end
end
