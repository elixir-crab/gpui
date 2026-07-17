defmodule GPUI.Dev.Visual.Scenario do
  @moduledoc false

  @type action ::
          {:dispatch, map()}
          | {:send_view, pos_integer(), term()}
          | {:hover, non_neg_integer(), non_neg_integer(), pos_integer()}
          | {:move_mouse, non_neg_integer(), non_neg_integer()}

  @type capture :: %{
          required(:name) => String.t(),
          optional(:actions) => [action()],
          optional(:after) => [action()]
        }

  @callback id() :: atom()
  @callback app() :: module()
  @callback args(:light | :dark) :: term()
  @callback title() :: String.t()
  @callback captures() :: [capture()]
end
