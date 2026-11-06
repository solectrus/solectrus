require 'rake'

describe RakeHelper do
  subject(:helper) { Object.new.extend(described_class) }

  before do
    allow(Rake.application).to receive(:top_level_tasks).and_return(tasks)
  end

  context 'with a task that runs before the database is ready' do
    let(:tasks) { %w[db:migrate] }

    it { is_expected.to be_skip_initialization }

    it 'knows the task' do
      expect(helper.rake_task_running?('db:migrate', 'db:seed')).to be(true)
    end
  end

  context 'with another task' do
    let(:tasks) { %w[db:seed] }

    it { is_expected.not_to be_skip_initialization }
  end
end
