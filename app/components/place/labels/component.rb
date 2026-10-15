# The icons of the labels of a place, for example a house for home. The name
# of each label is there for a screen reader and as a tooltip.
class Place::Labels::Component < ViewComponent::Base
  def initialize(place:)
    super()
    @place = place
  end

  def call
    safe_join(@place.labels.map { label_icon(it) })
  end

  private

  def label_icon(label)
    name = Place.human_label(label)
    tag.span(class: 'shrink-0 text-gray-500 dark:text-gray-400', title: name, data: { controller: 'tooltip' }) do
      icon(Place::LABELS[label]) + tag.span(name, class: 'sr-only')
    end
  end
end
