class InsightsTile::Component < ViewComponent::Base
  renders_one :title
  renders_one :body
  renders_one :footer

  def initialize(url: nil, class: nil, stripes: false)
    super
    @url = url
    @css_class = binding.local_variable_get(:class)
    @stripes = stripes
  end

  attr_reader :url, :css_class, :stripes

  def container_classes
    class_names(
      'sm:bg-gray-100 sm:dark:bg-slate-800 text-gray-900 dark:text-gray-400 rounded-2xl sm:shadow sm:p-4 sm:text-center',
      css_class,
      'sm:stripes' => stripes,
      'block sm:hover:scale-105 sm:transition-all' => url,
    )
  end

  def link_or_div(&)
    if url
      link_to url, class: container_classes, &
    else
      content_tag :div, class: container_classes, &
    end
  end
end
