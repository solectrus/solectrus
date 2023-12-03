describe Scale do
  context 'when initialized with a max value' do
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
  end

  context 'when initialized with max value of NIL' do
    let(:max) { nil }

    it { expect_result(0, 0) }
    it { expect_result(1000, 100) }
    it { expect_result(10_000, 100) }
  end

  context 'when initialized with a max value of 0' do
    let(:max) { 0 }

    it { expect_result(nil, 0) }

    it { expect_result(0, 0) }
    it { expect_result(1000, 100) }
    it { expect_result(10_000, 100) }
  end

  context 'when values are greater than max' do
    let(:max) { 500 }

    it { expect_result(0, 0) }
    it { expect_result(250, 49) }
    it { expect_result(1000, 100) } # 1000 > 500
    it { expect_result(10_000, 100) } # 10000 > 500
  end

  context 'when values are negative' do
    let(:max) { 500 }

    it { expect_result(-1, 0) }
  end

  private

  def expect_result(value, percent)
    expect(Scale.new(max:).result(value)).to eq(percent)
  end
end
