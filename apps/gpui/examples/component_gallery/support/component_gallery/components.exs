defmodule Examples.ComponentGallery.Components do
  @moduledoc false

  import GPUI.Template, only: [sigil_GPUI: 2]

  def canvas(title, child) do
    assigns = %{title: title, child: child}

    ~GPUI"""
    <div class="flex grow items-start justify-center pt-10">
      <div class="flex flex-col w-[620px] gap-5">
        <text class="text-sm font-semibold text-slate-500">{assigns.title}</text>
        <div class="flex flex-col gap-4 border border-slate-200 rounded-lg p-6 bg-white">{assigns.child}</div>
      </div>
    </div>
    """
  end

  def collection_canvas(title, child, width) do
    assigns = %{title: title, child: child, width: width}

    ~GPUI"""
    <div class="flex grow items-start justify-center pt-4">
      <div class={"flex flex-col h-[580px] gap-3 " <> assigns.width}>
        <text class="text-sm font-semibold text-slate-500">{assigns.title}</text>
        <div class="flex grow min-h-0 border border-slate-200 rounded-lg p-3 bg-white">{assigns.child}</div>
      </div>
    </div>
    """
  end
end
