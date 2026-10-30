# The labels of a place, each as a Ui::Badge with its icon and its name, for
# example a house for home.
class Place::Labels::Component < ViewComponent::Base
  def initialize(place:)
    super()
    @place = place
  end

  def call
    safe_join(@place.labels.map { label_badge(it) })
  end

  private

  def label_badge(label)
    render Ui::Badge::Component.new(color: :indigo).with_content(icon(Place::LABELS[label]) + Place.human_label(label))
  end
end
