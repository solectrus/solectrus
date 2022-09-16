describe Scale do
  let(:max) { 10_000 }

  it { expect_result(0, 0) }
  it { expect_result(1000, 18) }
  it { expect_result(2000, 32) }
  it { expect_result(3000, 43) }
  it { expect_result(4000, 53) }
  it { expect_result(5000, 63) }
  it { expect_result(6000, 71) }
  it { expect_result(7000, 79) }
  it { expect_result(8000, 86) }
  it { expect_result(9000, 93) }
  it { expect_result(10_000, 100) }

  def expect_result(value, percent)
    expect(Scale.new(max:).result(value)).to eq(percent)
  end
end
