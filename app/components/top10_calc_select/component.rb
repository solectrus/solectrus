class Top10CalcSelect::Component < ViewComponent::Base
  def peak?
    helpers.calc == 'peak'
  end

  def sum?
    helpers.calc == 'sum'
  end
end
