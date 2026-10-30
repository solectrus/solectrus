# The notes of the info tooltips of the columns of the comparison with a
# combustion car (see Car::ComparisonColumns::Component). A note without
# something to say stays out. The component has the comparison and its
# amounts (see Car::ComparisonAmounts).
module Car::ComparisonNotes
  # The info tooltip of each column: what it is, and how its energy costs.
  # The combustion car adds the costs that it shares with the car, and its
  # tax.
  def car_notes = [t('.notes.car_intro'), t('.notes.car')]
  def without_pv_notes = [t('.notes.without_pv_intro'), t('.notes.without_pv')]
  def combustion_notes = [t('.notes.combustion_intro'), t('.notes.fuel'), *shared_notes, tax_note].compact

  private

  # The notes of the running costs that the combustion car shares with the
  # car, and why its maintenance counts at the same amount
  def shared_notes
    [t('.notes.shared'), t('.notes.maintenance')] if amounts.shared_cost.nonzero?
  end

  def tax_note
    yearly = comparison.yearly_tax
    t('.notes.tax', yearly: currency(yearly)) if yearly&.positive?
  end
end
