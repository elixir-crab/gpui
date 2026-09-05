defmodule GPUI.Maintainer.Visual.Scenario do
  @moduledoc "Value describing one development visual-capture scenario."

  @type action ::
          {:dispatch, map()}
          | {:send_view, pos_integer(), term()}
          | {:send_view_from, pos_integer(), (map() -> term())}
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
