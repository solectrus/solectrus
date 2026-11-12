# The heating that burns oil or gas, which the heat pump compares with (see
# Heatpump::Comparison). The admin sets it up in the settings. Its values
# live in Setting, so there is one heating for the heat pump.
#
# The efficiency is the share of the energy in the fuel that heats the house
# over the year, in percent of the gross calorific value. A gas bill and the
# gas prices count each kWh by this value, so a gas heating needs no
# conversion. A condensing boiler reaches 75 to 90 % in daily use, a boiler
# without condensing 70 to 80 %, well below the data sheet. The default is
# 85 % (see Setting), the mean of the condensing boilers in a field test
# (see docs/heatpump.md).
#
# The fixed costs are all running costs of the heating per year, like the
# maintenance and the chimney sweep. The page calls them running costs. The
# standing charge of the gas is no part of them, because the gas price holds
# it already.
class Heatpump::Heating
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Attributes::Normalization

  # Each fuel by its unit of sale, the energy of that unit by its gross
  # calorific value, and the decimals of its price. Heating oil is sold by
  # the liter, gas by the kWh, whose price has a few cents and so a decimal
  # more.
  Fuel = Data.define(:unit, :kwh_per_unit, :price_precision)
  FUELS = {
    'heating_oil' => Fuel.new(unit: 'l', kwh_per_unit: 10.6, price_precision: 2),
    'gas' => Fuel.new(unit: 'kWh', kwh_per_unit: 1, price_precision: 3),
  }.freeze
  FUEL_TYPES = FUELS.keys.freeze
  public_constant :Fuel, :FUELS, :FUEL_TYPES

  EFFICIENCY = (50..100)
  public_constant :EFFICIENCY

  attribute :fuel_type, :string
  attribute :efficiency, :integer
  attribute :fixed_costs, :float

  # A blank select is no fuel. A blank number is nil already.
  normalizes :fuel_type, with: -> { it.presence }

  validates :fuel_type, inclusion: { in: FUEL_TYPES }, allow_nil: true
  validates :efficiency, presence: true, numericality: { only_integer: true, in: EFFICIENCY, allow_nil: true }, if: :configured?
  validates :fixed_costs, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # The saved heating, or the default of Setting before the admin saves one.
  # Without a fuel, the efficiency and the fixed costs have no use, so they
  # stay empty: the setting of the efficiency would give its default.
  def self.current
    fuel_type = Setting.heatpump_heating_fuel_type.presence
    return new unless fuel_type

    new(fuel_type:, efficiency: Setting.heatpump_heating_efficiency, fixed_costs: Setting.heatpump_heating_fixed_costs)
  end

  def self.human_fuel_type(fuel_type) = I18n.t("activemodel.attributes.heatpump/heating.fuel_types.#{fuel_type}")

  # Without a fuel, the efficiency and the fixed costs are cleared. The fuel
  # is saved as an empty string then, because nil would give its default.
  def save # rubocop:disable Naming/PredicateMethod
    self.efficiency = self.fixed_costs = nil unless configured?
    return false unless valid?

    Setting.heatpump_heating_fuel_type = fuel_type.to_s
    Setting.heatpump_heating_efficiency = efficiency
    Setting.heatpump_heating_fixed_costs = fixed_costs
    true
  end

  # Whether the heating has a fuel, without which there is no comparison
  def configured? = fuel_type.present?

  # The unit, the energy and the decimals of the price of the fuel (see
  # FUELS), nil without a fuel
  def fuel = FUELS[fuel_type]

  # The efficiency as a ratio
  def efficiency_ratio = efficiency / 100.0

  def fuel_prices = @fuel_prices ||= FuelPrices.new(fuel_type)

  def human_fuel_type = (self.class.human_fuel_type(fuel_type) if configured?)

  # The name of the heating, like "oil heating"
  def name = (I18n.t("heatpump_comparison.heating.#{fuel_type}") if configured?)

  # The settings always exist, so the form updates them
  def persisted? = true
end
