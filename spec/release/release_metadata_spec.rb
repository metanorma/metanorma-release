# frozen_string_literal: true

RSpec.describe Metanorma::Release::ReleaseMetadata do
  let(:sample_data) do
    {
      'version' => 1,
      'id' => 'cc-18011',
      'title' => 'Date and time — Explicit representation',
      'edition' => '1',
      'stage' => 'published',
      'doctype' => 'standard',
      'revdate' => '2018-06-01',
      'formats' => %w[html pdf xml rxl],
      'channels' => ['public/standards'],
      'flavor' => 'cc',
      'sourcePath' => 'sources/cc-18011.adoc'
    }
  end

  describe '.from_json' do
    it 'parses valid JSON' do
      json = JSON.generate(sample_data)
      meta = described_class.from_json(json)
      expect(meta.id).to eq('cc-18011')
      expect(meta.title).to eq('Date and time — Explicit representation')
    end

    it 'raises on missing id' do
      data = sample_data.reject { |k, _| k == 'id' }
      expect { described_class.from_json(JSON.generate(data)) }
        .to raise_error(ArgumentError, /id/)
    end

    it 'raises on missing title' do
      data = sample_data.reject { |k, _| k == 'title' }
      expect { described_class.from_json(JSON.generate(data)) }
        .to raise_error(ArgumentError, /title/)
    end
  end

  describe '.from_release_body' do
    let(:body) do
      "content-hash:abc123\n<!-- mn-release-metadata\n#{JSON.generate(sample_data)}\n-->"
    end

    it 'extracts metadata from HTML comment' do
      meta = described_class.from_release_body(body)
      expect(meta).not_to be_nil
      expect(meta.id).to eq('cc-18011')
    end

    it 'returns nil when no metadata comment found' do
      expect(described_class.from_release_body('no metadata here')).to be_nil
    end

    it 'returns nil for nil body' do
      expect(described_class.from_release_body(nil)).to be_nil
    end

    it 'returns nil when JSON parse fails' do
      bad_body = "<!-- mn-release-metadata\n{invalid json}\n-->"
      expect(described_class.from_release_body(bad_body)).to be_nil
    end
  end

  describe '#to_release_body' do
    it 'produces valid HTML comment' do
      meta = described_class.new(sample_data)
      body = meta.to_release_body
      expect(body).to start_with('<!-- mn-release-metadata')
      expect(body).to end_with('-->')
    end
  end

  describe 'round-trip' do
    it 'preserves data through from_release_body → to_release_body' do
      meta = described_class.new(sample_data)
      body = meta.to_release_body
      parsed = described_class.from_release_body(body)
      expect(parsed.id).to eq(meta.id)
      expect(parsed.title).to eq(meta.title)
      expect(parsed.edition).to eq(meta.edition)
      expect(parsed.stage).to eq(meta.stage)
      expect(parsed.channels).to eq(meta.channels)
    end
  end
end
