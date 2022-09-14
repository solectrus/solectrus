describe Scale do
  let(:max) { 10_000 }

  it { expect_result(0, 0) }
  it { expect_result(1000, 32) }
  it { expect_result(2000, 46) }
  it { expect_result(3000, 57) }
  it { expect_result(4000, 66) }
  it { expect_result(5000, 73) }
  it { expect_result(6000, 80) }
  it { expect_result(7000, 85) }
  it { expect_result(8000, 91) }
  it { expect_result(9000, 96) }
  it { expect_result(10_000, 100) }

  def expect_result(value, percent)
    expect(Scale.new(max:).result(value)).to eq(percent)
  end
end
