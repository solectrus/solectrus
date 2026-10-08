module PlaceHelper
  # The class that shows the hint of a label in the edit form while its chip
  # is on. Tailwind finds only literal class names, so each label names its
  # own.
  LABEL_HINT_CLASSES = { 'home' => 'group-has-[[value=home]:checked]/labels:visible' }.freeze
  private_constant :LABEL_HINT_CLASSES

  def place_label_hint_class(label) = LABEL_HINT_CLASSES[label]

  # The icons of the labels of a place, for example a house for home. The
  # name of each label is there for a screen reader and as a tooltip.
  def place_label_icons(place)
    safe_join(
      place.labels.map do |label|
        name = Place.human_label(label)
        tag.span(class: 'shrink-0 text-gray-500 dark:text-gray-400', title: name, data: { controller: 'tooltip' }) do
          icon(Place::LABELS[label]) + tag.span(name, class: 'sr-only')
        end
      end,
    )
  end
end
