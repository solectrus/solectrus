module UpdateCheck::SignatureCache
  private

  # Return memoized result if signature unchanged, otherwise re-verify
  def resolve_cached(cached_data)
    sig = cached_data[:signature]
    return @verified_result if @verified_result && @last_verified_signature == sig

    if signature_valid?(cached_data)
      @last_verified_signature = sig
      return @verified_result = verified_data(cached_data)
    end

    reset_verified_cache!
    Rails.logger.error('UpdateCheck: invalid signature in cache, clearing')
    @cache_manager.delete
    { registration_status: 'unknown' }
  end

  def reset_verified_cache!
    @verified_result = nil
    @last_verified_signature = nil
  end

  def signature_valid?(data)
    UpdateCheck::SignatureVerifier.new(data).verify!
  rescue UpdateCheck::SignatureVerifier::InvalidSignatureError
    false
  end

  def verified_data(data)
    data.except(:signature)
  end
end
