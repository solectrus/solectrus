# This class adjusts the PowerSplitter values for house, heatpump and wallbox
# to match the grid_import_power.
#
class Calculator::PowerSplitterCorrector
  def initialize(params)
    @grid_import_power = params[:grid_import_power]
    @house_power = params[:house_power]
    @house_power_grid = params[:house_power_grid]
    @heatpump_power = params[:heatpump_power]
    @heatpump_power_grid = params[:heatpump_power_grid]
    @wallbox_power = params[:wallbox_power]
    @wallbox_power_grid = params[:wallbox_power_grid]
  end

  attr_reader :grid_import_power,
              :house_power,
              :house_power_grid,
              :heatpump_power,
              :heatpump_power_grid,
              :wallbox_power,
              :wallbox_power_grid

  def adjusted_house_power_grid
    adjusted[:house_power_grid]
  end

  def adjusted_wallbox_power_grid
    adjusted[:wallbox_power_grid]
  end

  def adjusted_heatpump_power_grid
    adjusted[:heatpump_power_grid]
  end

  private

  def adjusted
    @adjusted ||= adjusted_grid_power
  end

  def adjusted_grid_power
    remaining = missing_grid
    result = initial_result

    count = 0
    loop do
      break if remaining < 1

      count += 1
      # Prevent infinite loop, just in case...
      if count > 10
        Rails.logger.warn('PowerSplitterCorrector: Too many iterations')
        break
      end

      available = {
        wallbox_power_grid: gap(wallbox_power, result[:wallbox_power_grid]),
        heatpump_power_grid: gap(heatpump_power, result[:heatpump_power_grid]),
        house_power_grid: gap(house_power, result[:house_power_grid]),
      }.compact

      total_available = available.values.sum
      break if total_available < 1

      available.each do |key, max_possible|
        next if max_possible < 1

        share = (remaining * max_possible.fdiv(total_available))
        increment = share.clamp(0, max_possible)
        result[key] += increment
        remaining -= increment
      end
    end

    result.transform_values(&:round)
  end

  def gap(power, power_grid)
    power - power_grid if power && power_grid
  end

  # First, clamp the grid values to the maximum possible values
  def initial_result
    @initial_result ||= {
      house_power_grid: house_power_grid&.clamp(0, house_power),
      wallbox_power_grid: wallbox_power_grid&.clamp(0, wallbox_power),
      heatpump_power_grid: heatpump_power_grid&.clamp(0, heatpump_power),
    }.compact
  end

  # The gap between the grid_import_power and the initial sum of grid power
  def missing_grid
    return 0 if grid_import_power.nil?

    grid_import_power - initial_result.values.sum
  end
end
