# Whether a signed answer belongs to this installation, and whether it still
# counts.
#
# The update server addresses every answer to one installation and gives it a
# moment where it stops being fresh, and it signs both with the rest of it.
# The two moments the cache keeps beside an answer are written by this
# installation, so they answer neither question.
#
# An expired answer is not always refused at once. A cached one is served for a
# while longer when the update server cannot be reached, so the caller allows
# that window with `grace`: without it, an outage of half a day would take the
# features off every installation (see UpdateCheck::Refresh::STALE_GRACE_PERIOD).
# An answer that just arrived gets no grace. The update server was reachable
# then, so an expired answer on the wire is one played back.
class UpdateCheck::BindingVerifier
  class InvalidBindingError < StandardError; end

  # How far the clock of an installation may run ahead of the update server
  # without its answer counting as expired. A clock that nobody keeps drifts,
  # and an answer is written for hours, so a few minutes decide nothing about
  # what it says.
  CLOCK_SKEW = 5.minutes
  private_constant :CLOCK_SKEW

  def initialize(data)
    @data = data
  end

  def verify!(grace: 0)
    raise InvalidBindingError, 'Missing setup id' if setup_id.blank?

    unless setup_id == own_setup_id
      raise InvalidBindingError, 'Answer of another installation'
    end

    raise InvalidBindingError, 'Missing expiry' if expires_at.nil?
    raise InvalidBindingError, 'Expired answer' unless valid_until(grace:).future?
  end

  # The moment the update server gave this answer, signed with the rest of it.
  # Nothing beside the answer decides when it stops being fresh.
  #
  # Time.zone.parse answers nil for a blank or unreadable value and raises only
  # for one that reads like a date and is none, such as "2026-13-45".
  def expires_at
    Time.zone.parse(@data[:expires_at].to_s)
  rescue ArgumentError
    nil
  end

  # The moment this answer stops counting, the drift of an unkept clock and the
  # grace of the caller included. The caller keeps it beside the verified
  # answer and asks it again on every call, which is far cheaper than verifying
  # the whole binding (see UpdateCheck::SignatureCache).
  def valid_until(grace: 0)
    expires_at + CLOCK_SKEW + grace
  end

  private

  def setup_id
    @data[:setup_id].to_s
  end

  # The update server keeps it as a string, this app as a number.
  def own_setup_id
    Setting.setup_id.to_s
  end
end
