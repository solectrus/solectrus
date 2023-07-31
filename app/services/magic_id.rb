class MagicId
  def encode(number)
    raise ArgumentError unless number.is_a?(Integer)

    payload = number.to_s(36)
    encrypt("#{payload},#{nonce}")
  end

  private

  def encrypt(data)
    iv = SecureRandom.random_bytes(16)

    cipher = OpenSSL::Cipher.new('aes-256-cbc')
    cipher.encrypt
    cipher.key = key
    cipher.iv = iv

    Base64.urlsafe_encode64(
      iv + cipher.update(data) + cipher.final,
      padding: false,
    )
  end

  def nonce
    SecureRandom.alphanumeric(7)
  end

  def key
    OpenSSL::Digest.digest('SHA256', 'no-secret-required')
  end
end
