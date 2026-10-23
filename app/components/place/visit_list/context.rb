# What the rows of the list of the visits share: the timeframe, whether the
# car needs a column, and the path to the list in another timeframe, for the
# header of a group
Place::VisitList::Context = Data.define(:timeframe, :car_column, :path) do
  def car_column? = car_column

  def list_path(**changes) = path.call(**changes)
end
