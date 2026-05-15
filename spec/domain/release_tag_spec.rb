# frozen_string_literal: true

RSpec.describe Metanorma::Release::ReleaseTag do
  let(:doc_id) { Metanorma::Release::DocumentId.from_raw('CC 18011') }

  describe '.from' do
    it 'creates published tag cc-18011/ed1' do
      version = Metanorma::Release::DocumentVersion.published(edition: '1')
      tag = described_class.from(doc_id, version)
      expect(tag.to_s).to eq('cc-18011/ed1')
      expect(tag).not_to be_pre_release
    end

    it 'creates draft tag cc-18011/ed1-wd' do
      stage = Metanorma::Release::DocumentStage.from_status('working-draft')
      version = Metanorma::Release::DocumentVersion.from('1', stage)
      tag = described_class.from(doc_id, version)
      expect(tag.to_s).to eq('cc-18011/ed1-wd')
      expect(tag).to be_pre_release
    end
  end

  describe '.create' do
    it 'creates tag with explicit pre_release flag' do
      tag = described_class.create('cc-18011/ed1', pre_release: false)
      expect(tag.to_s).to eq('cc-18011/ed1')
    end

    it 'raises without slash' do
      expect { described_class.create('cc-18011', pre_release: false) }
        .to raise_error(ArgumentError, /slash/)
    end
  end

  describe '.parse' do
    it 'extracts tag from cc-18011/ed1' do
      tag = described_class.parse('cc-18011/ed1')
      expect(tag.to_s).to eq('cc-18011/ed1')
      expect(tag).not_to be_pre_release
    end

    it 'detects pre-release from version suffix' do
      tag = described_class.parse('cc-18011/ed1-wd')
      expect(tag).to be_pre_release
    end

    it 'detects pre-release for committee-draft' do
      tag = described_class.parse('cc-18011/ed1-cd')
      expect(tag).to be_pre_release
    end

    it 'raises on missing slash' do
      expect { described_class.parse('cc-18011') }.to raise_error(ArgumentError, /slash/)
    end
  end

  describe 'round-trip' do
    it 'to_s roundtrips through parse' do
      version = Metanorma::Release::DocumentVersion.published(edition: '1')
      tag = described_class.from(doc_id, version)
      expect(described_class.parse(tag.to_s).to_s).to eq(tag.to_s)
    end
  end

  describe 'equality' do
    it 'same tag string is equal' do
      a = described_class.create('cc-18011/ed1', pre_release: false)
      b = described_class.create('cc-18011/ed1', pre_release: false)
      expect(a).to eql(b)
    end

    it 'different tag is not equal' do
      a = described_class.create('cc-18011/ed1', pre_release: false)
      b = described_class.create('cc-18011/ed2', pre_release: false)
      expect(a).not_to eql(b)
    end
  end
end
