describe RoundedSum do
  it 'rounds the parts to add up to the sum as shown' do
    rounded = described_class.new([2.323, 3.504], unit: :money)

    expect(rounded.parts).to eq([2.32, 3.51])
    expect(rounded.sum).to eq(5.83)
    expect(rounded.precision).to eq(2)
  end

  it 'keeps the cents of a small amount' do
    rounded = described_class.new([4.83, 10.2], unit: :money)

    expect(rounded.parts).to eq([4.83, 10.2])
    expect(rounded.sum).to eq(15.03)
    expect(rounded.precision).to eq(2)
  end

  it 'rounds to whole amounts when all of them are large' do
    rounded = described_class.new([43.28, 12.35], unit: :money)

    expect(rounded.parts).to eq([43, 13])
    expect(rounded.sum).to eq(56)
  end

  # 20 - 30 would be -10, which the range does not allow
  it 'rounds the parts on their own when the range clamps the sum' do
    rounded = described_class.new([20.4, -30.4], range: (0..), unit: :watt)

    expect(rounded.parts).to eq([20, -30])
    expect(rounded.sum).to eq(0)
  end

  it 'prints all values with the options of the sum' do
    rounded =
      described_class.new(
        [1_234_400, 3_288_480],
        unit: :watt,
        context: :total,
        scaling: 4_522_880,
      )

    expect(rounded.options).to eq(
      context: :total,
      scaling: 4_522_880,
      precision: 1,
    )
  end

  it 'rounds energy to the digits of the scaled sum' do
    rounded =
      described_class.new(
        [1_234_400, 3_288_480],
        unit: :watt,
        context: :total,
        precision: 3,
        scaling: 4_522_880,
      )

    # 1,234 + 3,288 would show 4,522 MWh, the sum shows 4,523 MWh
    expect(rounded.parts).to eq([1_234_000, 3_289_000])
    expect(rounded.sum).to eq(4_523_000)
  end

  it 'leaves the values as they are when one is missing' do
    rounded = described_class.new([2.323, nil], unit: :money)

    expect(rounded.parts).to eq([2.323, nil])
    expect(rounded.sum).to be_nil
    expect(rounded.precision).to be_nil
    expect(rounded.options).to eq({})
  end
end
