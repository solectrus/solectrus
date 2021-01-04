class BaseCalculator
  def build_context(hash)
    hash.each do |key, value|
      instance_variable_set(:"@#{key}", value)

      define_singleton_method(key) do
        instance_variable_get(:"@#{key}")
      end
    end
  end

  def live?
    time && time > 10.seconds.ago
  end

  def bat_charging?
    return unless bat_power_plus && bat_power_minus

    bat_power_plus > bat_power_minus
  end
end
