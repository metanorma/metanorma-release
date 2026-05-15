# frozen_string_literal: true

RSpec.describe Metanorma::Release::ContentHashChangeDetector do
  let(:detector) { described_class.new(previous_releases: {}) }

  let(:sample_metadata) do
    instance_double(
      Metanorma::Release::DocumentMetadata,
      output_dir: '/tmp/test',
      file_base_name: 'cc-18011'
    )
  end

  let(:tag) { Metanorma::Release::ReleaseTag.create('cc-18011/ed1', pre_release: false) }

  describe '#detect' do
    it 'reports changed for new document' do
      allow(Metanorma::Release::ContentHash).to receive(:of_directory)
        .and_return(Metanorma::Release::ContentHash.from_hex('abc'))

      result = detector.detect(sample_metadata, tag)
      expect(result).to be_changed
    end

    it 'reports not changed when hashes match' do
      hash = Metanorma::Release::ContentHash.from_hex('abc')
      allow(Metanorma::Release::ContentHash).to receive(:of_directory).and_return(hash)
      det = described_class.new(previous_releases: { 'cc-18011/ed1' => hash })

      result = det.detect(sample_metadata, tag)
      expect(result).not_to be_changed
    end

    it 'reports changed when content differs' do
      old_hash = Metanorma::Release::ContentHash.from_hex('old')
      new_hash = Metanorma::Release::ContentHash.from_hex('new')
      allow(Metanorma::Release::ContentHash).to receive(:of_directory).and_return(new_hash)
      det = described_class.new(previous_releases: { 'cc-18011/ed1' => old_hash })

      result = det.detect(sample_metadata, tag)
      expect(result).to be_changed
    end

    it 'always reports changed when force is true' do
      hash = Metanorma::Release::ContentHash.from_hex('same')
      allow(Metanorma::Release::ContentHash).to receive(:of_directory).and_return(hash)
      det = described_class.new(previous_releases: { 'cc-18011/ed1' => hash })

      result = det.detect(sample_metadata, tag, force: true)
      expect(result).to be_changed
    end
  end
end
