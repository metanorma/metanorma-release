# frozen_string_literal: true

require "tmpdir"
require "zip"

RSpec.describe Metanorma::Release::AssetProcessor do
  def create_zip(files)
    Dir.mktmpdir do |dir|
      zip_path = File.join(dir, "test.zip")
      Zip::File.open(zip_path, Zip::File::CREATE) do |zip|
        files.each do |name, content|
          zip.get_output_stream(name) { |s| s.write(content) }
        end
      end
      yield File.binread(zip_path)
    end
  end

  it "extracts zip and routes files by-document" do
    routing = Metanorma::Release::ByDocument.new
    Dir.mktmpdir do |output_dir|
      processor = described_class.new(output_dir: output_dir, routing: routing)
      create_zip({ "cc-18011-ed1.html" => "<html>", "cc-18011-ed1.pdf" => "PDF" }) do |zip_data|
        result = processor.process(zip_data, { "id" => "cc-18011" })
        expect(result.files.length).to eq(2)
        expect(result.files.map(&:name)).to include("cc-18011.html", "cc-18011.pdf")
        result.files.each do |f|
          expect(File.exist?(File.join(output_dir, f.path))).to be true
        end
      end
    end
  end

  it "canonicalizes edition suffixes" do
    routing = Metanorma::Release::Flat.new
    Dir.mktmpdir do |output_dir|
      processor = described_class.new(output_dir: output_dir, routing: routing, canonicalize: true)
      create_zip({ "cc-18011-ed1-wd.pdf" => "PDF" }) do |zip_data|
        result = processor.process(zip_data, { "id" => "cc-18011" })
        expect(result.files.first.name).to eq("cc-18011-wd.pdf")
      end
    end
  end

  it "preserves filenames when canonicalize is false" do
    routing = Metanorma::Release::Flat.new
    Dir.mktmpdir do |output_dir|
      processor = described_class.new(output_dir: output_dir, routing: routing, canonicalize: false)
      create_zip({ "cc-18011-ed1.pdf" => "PDF" }) do |zip_data|
        result = processor.process(zip_data, { "id" => "cc-18011" })
        expect(result.files.first.name).to eq("cc-18011-ed1.pdf")
      end
    end
  end

  it "handles empty zip" do
    routing = Metanorma::Release::Flat.new
    Dir.mktmpdir do |output_dir|
      processor = described_class.new(output_dir: output_dir, routing: routing)
      create_zip({}) do |zip_data|
        result = processor.process(zip_data, { "id" => "cc-18011" })
        expect(result.files).to be_empty
      end
    end
  end
end
