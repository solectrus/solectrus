module UpdateCheck::SignatureCache
  # How long a cached answer is served after the moment it names, because the
  # update server can be unreachable. The same window as the stale phase.
  GRACE = UpdateCheck::Refresh::STALE_GRACE_PERIOD
  private_constant :GRACE

  private

  # Whether a cached answer may be used, and its content if it may.
  #
  # Two questions are asked of it. Whether the update server wrote it, which
  # the signature answers, and whether it was written for this installation
  # and still counts, which the answer itself carries (see
  # UpdateCheck::BindingVerifier).
  #
  # Both are asked once per answer and the result is kept, because ApplicationPolicy
  # reaches this method some hundreds of times per request. Nothing the two
  # verifiers read can change while the signature does not - the setup id and
  # the expiry are signed with the rest. Only the moment passes while this
  # process runs, so that one is asked again every time.
  def resolve_cached(cached_data)
    if @verified_result && @last_verified_signature == cached_data[:signature]
      verify_deadline!
    else
      verify_and_memoize(cached_data)
    end

    @verified_result
  rescue UpdateCheck::SignatureVerifier::InvalidSignatureError,
         UpdateCheck::BindingVerifier::InvalidBindingError => e
    discard_cache(e.message)
  end

  def verify_and_memoize(data)
    UpdateCheck::BindingVerifier.new(data).verify!(grace: GRACE)
    UpdateCheck::SignatureVerifier.new(data).verify!

    memoize_verified(data)
  end

  # What a verified answer leaves behind: its content, the signature it was
  # verified under, and the moment it stops counting.
  #
  # UpdateCheck::Refresh#store_success calls this for an answer that arrived
  # over the wire, where UpdateCheck::HttpClient has verified both already.
  def memoize_verified(data)
    @last_verified_signature = data[:signature]
    @verified_until = UpdateCheck::BindingVerifier.new(data).valid_until(grace: GRACE)
    @verified_result = verified_data(data)
  end

  def verify_deadline!
    return if @verified_until.future?

    raise UpdateCheck::BindingVerifier::InvalidBindingError, 'Expired answer'
  end

  def reset_verified_cache!
    @verified_result = nil
    @last_verified_signature = nil
    @verified_until = nil
  end

  # An answer that cannot be used is not worth keeping either. Dropping it
  # makes the next call ask the update server again, which is what an
  # installation that expired its answer needs. The sensor list goes with it,
  # so nothing that the answer had opened outlives it.
  #
  # The retry throttle stays. A failed request sets it, and it keeps the next
  # requests away from a server that just did not answer. Clearing it here
  # would run one more request into the same timeout.
  def discard_cache(reason)
    Rails.logger.error("UpdateCheck: #{reason} in cache, clearing")
    drop_answer!

    UpdateCheck::Refresh::UNKNOWN
  end

  # The envelope is not part of the answer. The signature and the binding say
  # whether it may be read, nothing that reads it asks for them again.
  def verified_data(data)
    data.except(:signature, :setup_id, :expires_at)
  end
end
