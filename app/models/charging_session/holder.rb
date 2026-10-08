# Who charged in a session: a car, a guest, or nobody yet (see ChargingSession)
module ChargingSession::Holder
  # The holder of a guest charge (see #holder)
  GUEST = 'guest'.freeze
  public_constant :GUEST

  # Who charged, as one value for the form: the id of the car, GUEST for a
  # guest charge, or blank for "not assigned"
  def holder = guest? ? GUEST : car_id.to_s

  def holder=(value)
    self.guest = value == GUEST
    self.car_id = (value unless guest?).presence
  end

  # :car, :guest or :unassigned
  def state
    return :car if car_id
    return :guest if guest?

    :unassigned
  end
end
