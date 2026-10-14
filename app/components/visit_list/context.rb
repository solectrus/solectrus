# What the rows of the list of the visits share: the timeframe, the place the
# list is narrowed to, whether the car needs a column, and the path to the
# list with changes (see Cars::VisitsController#visits_path_with)
VisitList::Context = Data.define(:timeframe, :place, :car_column, :path) do
  def car_column? = car_column

  # The labels of the places need a column, but not in the list of a place
  # without a label
  def label_column? = !place || place.labels.any?

  # The columns of icons before the name of the place. A phone has them in
  # the line of the name, and the town below it starts after them.
  def icon_columns = [car_column?, label_column?].count(true)

  def list_path(**changes) = path.call(**changes)
end
