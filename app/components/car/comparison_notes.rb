# The notes of the info tooltips of the columns of the comparison with a
# combustion car (see Car::ComparisonColumns::Component). A note without
# something to say stays out. The component has the comparison and its
# amounts (see Car::ComparisonAmounts).
module Car::ComparisonNotes
  # The info tooltip of each column: what it is, how its energy costs, and
  # which payments add to it. The combustion car adds its tax and the costs
  # that it shares with the car.
  def car_notes = [t('.notes.car_intro'), t('.notes.car'), t('.notes.car_payments')]
  def without_pv_notes = [t('.notes.without_pv_intro'), t('.notes.without_pv'), t('.notes.without_pv_payments')]
  def combustion_notes = [t('.notes.combustion_intro'), t('.notes.fuel'), tax_note, *shared_notes].compact

  private

  # The notes of the running costs that the combustion car shares with the
  # car, and why its maintenance counts at the same amount
  def shared_notes
    [t('.notes.shared'), t('.notes.maintenance')] if amounts.shared_cost.nonzero?
  end

  def tax_note = (t('.notes.tax') if comparison.yearly_tax&.positive?)
end
