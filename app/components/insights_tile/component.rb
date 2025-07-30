class InsightsTile::Component < ViewComponent::Base
  renders_one :title
  renders_one :body
  renders_one :footer

  def initialize(url: nil, css_class: nil, stripes: false)
    super()
    @url = url
    @css_class = css_class
    @stripes = stripes
  end

  attr_reader :url, :css_class, :stripes

  def container_classes
    class_names(
      'bg-gray-100 dark:bg-slate-700 text-gray-900 dark:text-gray-400 rounded-2xl shadow p-4 text-center',
      css_class,
      'block' => url.present?,
      'sm:stripes' => stripes,
    )
  end

  def inner_container_classes
    class_names(
      'flex flex-col items-center justify-center',
      'block hover:scale-105 transition-all' => url,
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
