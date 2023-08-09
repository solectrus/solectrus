class MagicId
  def encode(number, secret)
    raise ArgumentError unless number.is_a?(Integer)
    raise ArgumentError unless secret.is_a?(String)

    payload = [number.to_s(36), secret].compact.join(':')
    encrypt(payload)
  end

  private

  def encrypt(data)
    iv = SecureRandom.random_bytes(12)

    cipher = OpenSSL::Cipher.new('aes-256-gcm')
    cipher.encrypt
    cipher.key = key
    cipher.iv = iv

    Base64.urlsafe_encode64(
      cipher.update(data) + cipher.final + iv + cipher.auth_tag, # rubocop:disable Rails/SaveBang
      padding: false,
    )
  end

  def key
    OpenSSL::Digest.digest('SHA256', 'no-secret-required')
  end
end
