module PlaceHelper
  # The class that shows the hint of a label in the edit form while its chip
  # is on. The modal keeps the space of a hidden hint, so it keeps its height.
  # The page of a phone leaves it out. Tailwind finds only literal class
  # names, so each label names its own.
  LABEL_HINT_CLASSES = {
    'home' => 'group-has-[[value=home]:checked]/labels:visible max-lg:hidden max-lg:group-has-[[value=home]:checked]/labels:block',
  }.freeze
  private_constant :LABEL_HINT_CLASSES

  def place_label_hint_class(label) = LABEL_HINT_CLASSES[label]
end
