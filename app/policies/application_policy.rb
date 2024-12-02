class ApplicationPolicy
  include Singleton

  SPONSOR_FEATURES = %i[power_splitter themes car heatpump custom].freeze
  private_constant :SPONSOR_FEATURES

  SPONSOR_FEATURES.each do |feature|
    define_singleton_method(:"#{feature}?") do
      instance.feature_enabled?(feature)
    end
  end

  def feature_enabled?(feature)
    SPONSOR_FEATURES.include?(feature) && (eligible_for_free? || sponsoring?)
  end

  delegate :eligible_for_free?, :sponsoring?, to: UpdateCheck
end
