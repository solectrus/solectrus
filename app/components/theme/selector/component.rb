# `cell: true` gives the selector the size of a segmented control, for the
# cell of a grouped list. Without a sponsorship, the cell says why the
# selector is pale.
class Theme::Selector::Component < ViewComponent::Base
  def initialize(cell: false)
    super()
    @cell = cell
  end

  def form_class
    if @cell
      ['gap-0.5 p-0.5 rounded-lg bg-slate-500/12 dark:bg-slate-900', ('opacity-40' unless ApplicationPolicy.themes?)]
    else
      'justify-evenly w-40 p-2 rounded-xl bg-indigo-200 lg:bg-gray-200 dark:bg-gray-950 opacity-80'
    end
  end

  def label_class
    @cell ? 'px-2.5 py-1 rounded-md has-[:checked]:shadow-sm' : 'p-2 rounded-lg'
  end

  def icon_class
    @cell ? 'size-5' : 'size-6'
  end
end
