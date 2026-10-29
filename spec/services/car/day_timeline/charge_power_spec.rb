describe Car::DayTimeline::ChargePower do
  def at(hour, minute = 0, second = 0) = Time.zone.local(2026, 6, 15, hour, minute, second)

  def power(from:, to:, power:, grid: nil) = described_class.new(from:, to:, power:, grid:).call

  def values(points) = points.map { [it.time, it.pv, it.grid, it.unsplit] }

  # Each bucket carries the end of its 5 minutes and stands at its middle
  it 'splits each bucket into PV and grid, from the start to the end of the charge' do
    points = power(from: at(12), to: at(12, 10), power: [[at(12, 5), 4000.0], [at(12, 10), 5000.0]], grid: [[at(12, 5), 1000.0], [at(12, 10), 0.0]])

    expect(values(points)).to eq(
      [
        [at(12), 3000.0, 1000.0, 0.0],
        [at(12, 2, 30), 3000.0, 1000.0, 0.0],
        [at(12, 7, 30), 5000.0, 0.0, 0.0],
        [at(12, 10), 5000.0, 0.0, 0.0],
      ],
    )
  end

  # The power splitter divides its own cycles
  it 'keeps the grid share within the power of its bucket' do
    points = power(from: at(12), to: at(12, 5), power: [[at(12, 5), 2000.0]], grid: [[at(12, 5), 2500.0]])

    expect(points.map { [it.pv, it.grid] }.uniq).to eq([[0.0, 2000.0]])
  end

  it 'leaves the power unsplit where the power splitter did not split it yet' do
    points = power(from: at(12), to: at(12, 10), power: [[at(12, 5), 4000.0], [at(12, 10), 5000.0]], grid: [[at(12, 5), 1000.0]])

    expect(points.last.unsplit).to eq(5000.0)
    expect(points.last.total).to eq(5000.0)
  end

  it 'leaves all power unsplit without the power splitter' do
    points = power(from: at(12), to: at(12, 5), power: [[at(12, 5), 4000.0]])

    expect(points.map(&:unsplit)).to eq([4000.0] * 3)
  end

  # The curve of the wallbox holds the buckets with power alone
  it 'has 0 W in a bucket without power, like in a pause' do
    points = power(from: at(12), to: at(12, 15), power: [[at(12, 5), 4000.0], [at(12, 15), 4000.0]])

    expect(points.map(&:total)).to eq([4000.0, 4000.0, 0.0, 4000.0, 4000.0])
  end

  # A charge that starts or ends within a bucket touches it
  it 'takes the buckets that the charge touches' do
    points = power(from: at(12, 2), to: at(12, 7), power: [[at(12, 5), 1000.0], [at(12, 10), 2000.0]])

    # The middle of the last bucket lies after the end
    expect(points.map(&:time)).to eq([at(12, 2), at(12, 2, 30), at(12, 7), at(12, 7)])
    expect(points.map(&:total)).to eq([1000.0, 1000.0, 2000.0, 2000.0])
  end

  # The last bucket of a day ends a second before midnight
  it 'takes the last bucket of the day' do
    points = power(from: at(23, 55), to: at(0) + 1.day, power: [[at(23, 59, 59), 3000.0]])

    expect(points.map(&:total)).to eq([3000.0] * 3)
  end

  it 'has no curve without power' do
    expect(power(from: at(12), to: at(12, 10), power: [])).to be_empty
  end
end
