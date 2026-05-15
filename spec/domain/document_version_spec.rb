# frozen_string_literal: true

RSpec.describe Metanorma::Release::DocumentVersion do
  describe '.from' do
    it 'creates published version with tag_component ed1' do
      v = described_class.from('1', Metanorma::Release::DocumentStage.published)
      expect(v.tag_component).to eq('ed1')
      expect(v).not_to be_pre_release
    end

    it 'creates draft version with tag_component ed2-wd' do
      stage = Metanorma::Release::DocumentStage.from_status('working-draft')
      v = described_class.from('2', stage)
      expect(v.tag_component).to eq('ed2-wd')
      expect(v).to be_pre_release
    end

    it 'defaults edition to 0 when nil' do
      v = described_class.from(nil, Metanorma::Release::DocumentStage.published)
      expect(v.edition).to eq('0')
    end

    it 'defaults edition to 0 when blank' do
      v = described_class.from('', Metanorma::Release::DocumentStage.published)
      expect(v.edition).to eq('0')
    end
  end

  describe '.published' do
    it 'creates published version' do
      v = described_class.published(edition: '1')
      expect(v.tag_component).to eq('ed1')
      expect(v).not_to be_pre_release
    end
  end

  describe '#file_name' do
    it 'combines doc_id + edition + stage suffix' do
      stage = Metanorma::Release::DocumentStage.from_status('working-draft')
      v = described_class.from('1', stage)
      expect(v.file_name('cc-18011')).to eq('cc-18011-ed1-wd.zip')
    end

    it 'omits stage suffix for published' do
      v = described_class.published(edition: '1')
      expect(v.file_name('cc-18011')).to eq('cc-18011-ed1.zip')
    end
  end

  describe 'equality' do
    it 'same edition and stage is equal' do
      a = described_class.published(edition: '1')
      b = described_class.from('1', Metanorma::Release::DocumentStage.published)
      expect(a).to eql(b)
    end

    it 'different edition is not equal' do
      a = described_class.published(edition: '1')
      b = described_class.published(edition: '2')
      expect(a).not_to eql(b)
    end
  end
end
