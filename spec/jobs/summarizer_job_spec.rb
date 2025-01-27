describe 'SummarizerJob' do
  subject(:job) { SummarizerJob.new }

  describe '#perform' do
    subject(:perform) { job.perform(date) }

    context 'when no summary exists for the given date' do
      let(:date) { Date.current }

      it 'creates Summary' do
        expect { perform }.to change(Summary, :count).by(1)
      end
    end

    context 'when fresh summary from today exists' do
      let(:date) { Date.current }

      let!(:summary) { Summary.create!(date:, updated_at: 1.minute.ago) }

      it 'does not create Summary' do
        expect { perform }.not_to change(Summary, :count)
      end

      it 'updates Summary' do
        expect { perform }.to(change { summary.reload.updated_at })
      end
    end

    context 'when fresh summary from the past exists' do
      let(:date) { Date.yesterday }

      let!(:summary) { Summary.create!(date:, updated_at: 1.minute.ago) }

      it 'does not create Summary' do
        expect { perform }.not_to change(Summary, :count)
      end

      it 'does not update Summary' do
        expect { perform }.not_to(change { summary.reload.updated_at })
      end
    end

    context 'when stale summary already exists' do
      let(:date) { Date.yesterday }

      let!(:summary) { Summary.create!(date:, updated_at: date.middle_of_day) }

      it 'does not create Summary' do
        expect { perform }.not_to change(Summary, :count)
      end

      it 'updates Summary' do
        expect { perform }.to(change { summary.reload.updated_at })
      end
    end
  end
end
