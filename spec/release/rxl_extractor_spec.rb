# frozen_string_literal: true

RSpec.describe Metanorma::Release::RxlExtractor do
  let(:fixtures_dir) { File.join(__dir__, "../fixtures/rxl") }

  describe "#extract" do
    it "parses valid RXL with id, title, edition, stage, doctype" do
      extractor = described_class.new
      meta = extractor.extract(File.join(fixtures_dir, "sample.rxl"))
      expect(meta.id.to_s).to eq("cc-18011-2018")
      expect(meta.title).to eq("Date and time — Explicit representation")
      expect(meta.version.edition).to eq("1")
      expect(meta.version.stage).to be_published
      expect(meta.doctype).to eq("standard")
    end

    it "parses ISO stage 30 as committee-draft" do
      extractor = described_class.new
      meta = extractor.extract(File.join(fixtures_dir, "multi_format.rxl"))
      expect(meta.version.stage.to_s).to eq("committee-draft")
    end

    it "detects document_type from identifier" do
      extractor = described_class.new
      meta = extractor.extract(File.join(fixtures_dir, "sample.rxl"))
      expect(meta.document_type).to eq("standard")
    end

    it "handles malformed RXL gracefully" do
      extractor = described_class.new
      meta = extractor.extract(File.join(fixtures_dir, "invalid.rxl"))
      expect(meta).not_to be_nil
      expect(meta.title).to eq("")
    end

    it "raises for missing file" do
      extractor = described_class.new
      expect { extractor.extract("/nonexistent.rxl") }.to raise_error(ArgumentError)
    end
  end

  describe "#discover" do
    it "returns empty array for empty directory" do
      Dir.mktmpdir do |dir|
        extractor = described_class.new
        expect(extractor.discover(dir)).to eq([])
      end
    end

    it "finds RXL files in nested directories" do
      extractor = described_class.new
      results = extractor.discover(fixtures_dir)
      expect(results.length).to be >= 2
    end
  end
end
