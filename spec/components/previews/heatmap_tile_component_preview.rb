# @label HeatmapTile
class HeatmapTileComponentPreview < ViewComponent::Preview # rubocop:disable Metrics/ClassLength
  def default
    data = {
      2022 => {
        1 => 150,
        2 => 180,
        3 => 220,
        4 => 280,
        5 => 350,
        6 => 400,
        7 => 420,
        8 => 380,
        9 => 300,
        10 => 250,
        11 => 180,
        12 => 140,
      },
      2023 => {
        1 => 160,
        2 => 190,
        3 => 240,
        4 => 290,
        5 => 380,
        6 => 420,
        7 => 450,
        8 => 400,
        9 => 320,
        10 => 270,
        11 => 200,
        12 => 150,
      },
      2024 => {
        1 => 170,
        2 => 200,
        3 => 250,
        4 => 300,
        5 => nil,
        6 => nil,
        7 => nil,
        8 => nil,
        9 => nil,
        10 => nil,
        11 => nil,
        12 => nil,
      },
    }

    render HeatmapTile::Component.new(
             data:,
             sensor: Sensor::Registry[:inverter_power],
             timeframe: Timeframe.all,
           )
  end

  def with_missing_data
    data = {
      2023 => {
        1 => 160,
        2 => nil,
        3 => 240,
        4 => 290,
        5 => 380,
        6 => 420,
        7 => nil,
        8 => 400,
        9 => 320,
        10 => nil,
        11 => 200,
        12 => 150,
      },
    }

    render HeatmapTile::Component.new(
             data:,
             sensor: Sensor::Registry[:house_power],
             timeframe: Timeframe.all,
           )
  end

  def single_year
    data = {
      2024 => {
        1 => 100,
        2 => 150,
        3 => 200,
        4 => 250,
        5 => 300,
        6 => 350,
        7 => 400,
        8 => 350,
        9 => 300,
        10 => 250,
        11 => 200,
        12 => 150,
      },
    }

    render HeatmapTile::Component.new(
             data:,
             sensor: Sensor::Registry[:grid_export_power],
             timeframe: Timeframe.all,
           )
  end

  def grid_power # rubocop:disable Metrics/MethodLength
    data = {
      2022 => {
        1 => {
          grid_costs: 420,
          grid_revenue: 15,
          grid_balance: -405,
        },
        2 => {
          grid_costs: 380,
          grid_revenue: 25,
          grid_balance: -355,
        },
        3 => {
          grid_costs: 320,
          grid_revenue: 45,
          grid_balance: -275,
        },
        4 => {
          grid_costs: 280,
          grid_revenue: 95,
          grid_balance: -185,
        },
        5 => {
          grid_costs: 180,
          grid_revenue: 150,
          grid_balance: -30,
        },
        6 => {
          grid_costs: 120,
          grid_revenue: 220,
          grid_balance: 100,
        },
        7 => {
          grid_costs: 100,
          grid_revenue: 280,
          grid_balance: 180,
        },
        8 => {
          grid_costs: 130,
          grid_revenue: 250,
          grid_balance: 120,
        },
        9 => {
          grid_costs: 200,
          grid_revenue: 160,
          grid_balance: -40,
        },
        10 => {
          grid_costs: 280,
          grid_revenue: 80,
          grid_balance: -200,
        },
        11 => {
          grid_costs: 350,
          grid_revenue: 35,
          grid_balance: -315,
        },
        12 => {
          grid_costs: 400,
          grid_revenue: 20,
          grid_balance: -380,
        },
      },
      2023 => {
        1 => {
          grid_costs: 450,
          grid_revenue: 18,
          grid_balance: -432,
        },
        2 => {
          grid_costs: 400,
          grid_revenue: 30,
          grid_balance: -370,
        },
        3 => {
          grid_costs: 340,
          grid_revenue: 55,
          grid_balance: -285,
        },
        4 => {
          grid_costs: 290,
          grid_revenue: 110,
          grid_balance: -180,
        },
        5 => {
          grid_costs: 190,
          grid_revenue: 180,
          grid_balance: -10,
        },
        6 => {
          grid_costs: 110,
          grid_revenue: 250,
          grid_balance: 140,
        },
        7 => {
          grid_costs: 90,
          grid_revenue: 320,
          grid_balance: 230,
        },
        8 => {
          grid_costs: 120,
          grid_revenue: 280,
          grid_balance: 160,
        },
        9 => {
          grid_costs: 210,
          grid_revenue: 170,
          grid_balance: -40,
        },
        10 => {
          grid_costs: 300,
          grid_revenue: 90,
          grid_balance: -210,
        },
        11 => {
          grid_costs: 380,
          grid_revenue: 40,
          grid_balance: -340,
        },
        12 => {
          grid_costs: 420,
          grid_revenue: 25,
          grid_balance: -395,
        },
      },
      2024 => {
        1 => {
          grid_costs: 480,
          grid_revenue: 22,
          grid_balance: -458,
        },
        2 => {
          grid_costs: 430,
          grid_revenue: 35,
          grid_balance: -395,
        },
        3 => {
          grid_costs: 360,
          grid_revenue: 65,
          grid_balance: -295,
        },
        4 => {
          grid_costs: 300,
          grid_revenue: 125,
          grid_balance: -175,
        },
        5 => nil,
        6 => nil,
        7 => nil,
        8 => nil,
        9 => nil,
        10 => nil,
        11 => nil,
        12 => nil,
      },
    }

    render HeatmapTile::Component.new(
             data:,
             sensor: Sensor::Registry[:grid_power],
             timeframe: Timeframe.all,
           )
  end
end
