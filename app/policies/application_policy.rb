class ApplicationPolicy
  include Singleton

  SPONSOR_FEATURES = %i[
    power_splitter
    themes
    car
    custom_consumer
    multi_inverter
    relative_timeframe
    insights
    heatpump
    finance_charts
    power_balance_chart
    finance_top10
  ].freeze
  private_constant :SPONSOR_FEATURES

  SPONSOR_FEATURES.each do |feature|
    define_singleton_method(:"#{feature}?") do
      instance.feature_enabled?(feature)
    end
  end

  def feature_enabled?(feature)
    SPONSOR_FEATURES.include?(feature) &&
      (eligible_for_free? || sponsoring? || free_trial?)
  end

  delegate :eligible_for_free?, :sponsoring?, :free_trial?, to: UpdateCheck
end
