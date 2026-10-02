describe 'Balance page (battery, grid & environment)' do
  it_behaves_like(
    'balance navigation',
    %w[
      battery_power
      battery_soc
      grid_power
      car_battery_soc_1
      case_temp
      co2_reduction
    ],
  )
end
