require 'icon_generator'

describe IconGenerator do
  subject(:generator) { described_class.new(list:, target:, packages:) }

  let(:dir) { Pathname.new(Dir.mktmpdir) }
  let(:list) { dir.join('icons.yml') }
  let(:target) { dir.join('icons.generated.yml') }
  let(:packages) { Rails.root.join('node_modules', '@fortawesome') }

  after { FileUtils.remove_entry(dir) }

  def write_list(content)
    File.write(list, content)
  end

  def generated
    YAML.load_file(target)
  end

  context 'with one icon per style' do
    before do
      write_list(<<~YAML)
        solid:
          - gear
        regular:
          - calendar
        brands:
          - github
      YAML
    end

    it 'reports how many it wrote' do
      expect(generator.call).to eq(3)
    end

    it 'writes the prefix each style renders with' do
      generator.call

      expect(generated.transform_values { |data| data['prefix'] }).to eq(
        'gear' => 'fas',
        'calendar' => 'far',
        'github' => 'fab',
      )
    end

    it 'writes the path data' do
      generator.call

      expect(generated.dig('gear', 'path')).to start_with('M')
    end

    it 'writes the size the viewBox needs' do
      generator.call

      expect(generated['gear']).to include('width' => 512, 'height' => 512)
    end

    # A wrapped path draws the same shape, but it stops the file from diffing
    # cleanly, which is the point of checking it in.
    it 'keeps every path on a single line' do
      generator.call

      expect(File.foreach(target).count { |line| line.include?(' path: ') })
        .to eq(3)
    end
  end

  context 'when the list names an alias' do
    before { write_list("solid:\n  - home\n") }

    it 'refuses it and names the canonical icon' do
      expect { generator.call }.to raise_error(
        described_class::Error,
        /alias.*Use house instead/,
      )
    end
  end

  context 'when the list names an icon that does not exist' do
    before { write_list("solid:\n  - no-such-icon\n") }

    it 'says which name and style it looked for' do
      expect { generator.call }.to raise_error(
        described_class::Error,
        /no-such-icon as solid/,
      )
    end
  end

  context 'when the list names an icon in the wrong style' do
    before { write_list("brands:\n  - gear\n") }

    it 'refuses it' do
      expect { generator.call }.to raise_error(described_class::Error)
    end
  end

  # The checked-in file is what the app renders from. If it drifts from the
  # list, an icon is missing or stale, and only a run of the task fixes it.
  describe 'the checked-in file' do
    it 'matches config/icons.yml' do
      described_class.new(target:).call

      expect(YAML.load_file(target)).to eq(
        YAML.load_file(Rails.root.join('config', 'icons.generated.yml')),
      )
    end
  end
end
