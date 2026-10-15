# `cell: true` gives the selector the size of a segmented control, for the
# cell of a grouped list
class Theme::ColorPaletteSelector::Component < ViewComponent::Base
  def initialize(cell: false)
    super()
    @cell = cell
  end

  def form_class
    if @cell
      'gap-0.5 p-0.5 rounded-lg bg-slate-500/12 dark:bg-slate-900'
    else
      'justify-center gap-4 w-40 p-2 rounded-xl bg-indigo-200 lg:bg-gray-200 dark:bg-gray-950 opacity-80'
    end
  end

  def tile_class
    @cell ? 'gap-0.5 rounded-md px-2 py-1.5 peer-checked:shadow-sm' : 'gap-1 rounded-lg p-2'
  end

  def swatch_class
    @cell ? 'w-3.5 h-2' : 'w-5 h-3'
  end
end
