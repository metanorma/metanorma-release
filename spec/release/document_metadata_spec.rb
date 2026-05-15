# frozen_string_literal: true

RSpec.describe Metanorma::Release::DocumentMetadata do
  let(:version) do
    Metanorma::Release::DocumentVersion.from('1', Metanorma::Release::DocumentStage.published)
  end

  let(:metadata) do
    described_class.new(
      id: Metanorma::Release::DocumentId.from_raw('CC 18011'),
      title: 'Test Doc',
      version: version,
      doctype: 'standard',
      document_type: 'standard',
      flavor: 'cc',
      revdate: '2025-06-01',
      source_path: 'sources/cc-18011.adoc',
      output_dir: '/tmp/test',
      formats: %w[html pdf],
      file_base_name: 'cc-18011'
    )
  end

  it 'is frozen' do
    expect(metadata).to be_frozen
  end

  describe 'attribute readers' do
    it 'exposes id as DocumentId' do
      expect(metadata.id).to be_a(Metanorma::Release::DocumentId)
      expect(metadata.id.to_s).to eq('cc-18011')
    end

    it 'exposes title' do
      expect(metadata.title).to eq('Test Doc')
    end

    it 'exposes version' do
      expect(metadata.version).to eq(version)
    end

    it 'exposes doctype' do
      expect(metadata.doctype).to eq('standard')
    end

    it 'exposes document_type' do
      expect(metadata.document_type).to eq('standard')
    end

    it 'exposes flavor' do
      expect(metadata.flavor).to eq('cc')
    end

    it 'exposes revdate' do
      expect(metadata.revdate).to eq('2025-06-01')
    end

    it 'exposes output_dir' do
      expect(metadata.output_dir).to eq('/tmp/test')
    end

    it 'exposes formats' do
      expect(metadata.formats).to eq(%w[html pdf])
    end

    it 'exposes file_base_name' do
      expect(metadata.file_base_name).to eq('cc-18011')
    end
  end

  describe '#[]' do
    it 'returns source_path' do
      expect(metadata['source_path']).to eq('sources/cc-18011.adoc')
    end

    it 'returns id as a DocumentId' do
      expect(metadata['id'].to_s).to eq('cc-18011')
    end

    it 'returns nil for unknown key' do
      expect(metadata['nonexistent']).to be_nil
    end
  end

  it 'freezes formats array' do
    expect(metadata.formats).to be_frozen
  end
end
