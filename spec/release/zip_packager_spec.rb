# frozen_string_literal: true

require 'zip'

RSpec.describe Metanorma::Release::ZipPackager do
  let(:packager) { described_class.new }

  def create_test_files(dir, files)
    files.each do |name, content|
      File.write(File.join(dir, name), content)
    end
  end

  def build_metadata(output_dir:, id: 'cc-18011', formats: %w[html pdf])
    Metanorma::Release::DocumentMetadata.new(
      id: Metanorma::Release::DocumentId.from_raw(id),
      title: 'Test', version: Metanorma::Release::DocumentVersion.published(edition: '1'),
      doctype: 'standard', document_type: 'standard',
      flavor: 'cc', revdate: '2024-01-01',
      source_path: "sources/#{id}.adoc", output_dir: output_dir,
      formats: formats, file_base_name: id
    )
  end

  describe '#package' do
    it 'creates a zip with matching files' do
      Dir.mktmpdir do |dir|
        create_test_files(dir, { 'cc-18011.html' => '<html/>', 'cc-18011.pdf' => 'PDF' })
        metadata = build_metadata(output_dir: dir)

        artifact = packager.package(metadata, canonical_base: 'cc-18011-ed1')

        expect(artifact.zip_path).to end_with('cc-18011-ed1.zip')
        expect(artifact.asset_name).to eq('cc-18011-ed1.zip')
        expect(artifact.size).to be > 0
        expect(File.exist?(artifact.zip_path)).to be true

        entries = Zip::File.open(artifact.zip_path) { |z| z.map(&:name) }
        expect(entries).to include('cc-18011-ed1.html', 'cc-18011-ed1.pdf')
      end
    end

    it 'includes only files matching the base name' do
      Dir.mktmpdir do |dir|
        create_test_files(dir, {
                            'cc-18011.html' => '<html/>',
                            'other-doc.pdf' => 'PDF'
                          })
        metadata = build_metadata(output_dir: dir)

        artifact = packager.package(metadata, canonical_base: 'cc-18011-ed1')

        entries = Zip::File.open(artifact.zip_path) { |z| z.map(&:name) }
        expect(entries).to include('cc-18011-ed1.html')
        expect(entries).not_to include('cc-18011-ed1.pdf')
      end
    end

    it 'replaces existing zip' do
      Dir.mktmpdir do |dir|
        create_test_files(dir, { 'cc-18011.html' => 'v1' })
        metadata = build_metadata(output_dir: dir)
        packager.package(metadata, canonical_base: 'cc-18011-ed1')

        create_test_files(dir, { 'cc-18011.html' => 'v2-longer-content' })
        artifact = packager.package(metadata, canonical_base: 'cc-18011-ed1')

        content = Zip::File.open(artifact.zip_path) { |z| z.read('cc-18011-ed1.html') }
        expect(content).to eq('v2-longer-content')
      end
    end
  end
end
