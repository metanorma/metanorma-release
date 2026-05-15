# frozen_string_literal: true

require "tmpdir"

RSpec.describe Metanorma::Release::DocumentIndex do
  let(:sample_doc_h) do
    {
      "id" => "cc-18011-2018",
      "title" => "Date and time",
      "edition" => "1",
      "stage" => "published",
      "doctype" => "",
      "channels" => ["public/standards"],
      "formats" => %w[html pdf xml rxl],
      "flavor" => "cc",
      "contentHash" => "abc123",
      "source" => {
        "owner" => "CalConnect",
        "repo" => "cc-datetime-explicit",
        "tag" => "cc-18011-2018/ed1",
        "releaseUrl" => "https://example.com",
        "releaseDate" => "2026-05-13T12:21:32Z"
      },
      "files" => [
        { "name" => "cc-18011-2018.html", "path" => "cc-18011-2018/cc-18011-2018.html" },
        { "name" => "cc-18011-2018.pdf", "path" => "cc-18011-2018/cc-18011-2018.pdf" }
      ]
    }
  end

  let(:valid_json) do
    JSON.generate({
      "version" => 1,
      "generatedAt" => "2026-05-14T10:30:00Z",
      "parameters" => {
        "organizations" => ["CalConnect"],
        "channels" => [],
        "topic" => "metanorma-release",
        "repoCount" => 51
      },
      "summary" => { "repoCount" => 51, "documentCount" => 1, "channelsFound" => ["public/standards"] },
      "documents" => [sample_doc_h]
    })
  end

  describe ".from_json" do
    it "parses valid v1 JSON" do
      index = described_class.from_json(valid_json)
      expect(index.document_count).to eq(1)
      expect(index.documents.first.id).to eq("cc-18011-2018")
    end

    it "raises on missing version" do
      json = JSON.generate("documents" => [])
      expect { described_class.from_json(json) }.to raise_error(described_class::SchemaError, /version/)
    end

    it "raises on wrong version" do
      json = JSON.generate("version" => 99, "documents" => [])
      expect { described_class.from_json(json) }.to raise_error(described_class::SchemaError, /version/)
    end

    it "raises on missing documents" do
      json = JSON.generate("version" => 1)
      expect { described_class.from_json(json) }.to raise_error(described_class::SchemaError, /documents/)
    end

    it "accepts empty documents array" do
      json = JSON.generate("version" => 1, "documents" => [])
      index = described_class.from_json(json)
      expect(index).to be_empty
    end

    it "raises on document missing id" do
      doc = sample_doc_h.reject { |k, _| k == "id" }
      json = JSON.generate("version" => 1, "documents" => [doc])
      expect { described_class.from_json(json) }.to raise_error(described_class::SchemaError, /id/)
    end
  end

  describe ".from_documents" do
    it "creates valid index from documents" do
      doc = Metanorma::Release::AggregatedDocument.from_h(sample_doc_h)
      params = Metanorma::Release::IndexParameters.new(
        organizations: ["CalConnect"], channels: [], topic: "test", repo_count: 1
      )
      index = described_class.from_documents([doc], parameters: params)
      expect(index.document_count).to eq(1)
      expect(index.channels).to eq(["public/standards"])
    end
  end

  describe "round-trip" do
    it "preserves data through to_json → from_json" do
      doc = Metanorma::Release::AggregatedDocument.from_h(sample_doc_h)
      params = Metanorma::Release::IndexParameters.new(
        organizations: ["CalConnect"], channels: [], topic: "test", repo_count: 1
      )
      index = described_class.from_documents([doc], parameters: params)
      json = index.to_json

      restored = described_class.from_json(json)
      expect(restored.document_count).to eq(1)
      expect(restored.documents.first.id).to eq("cc-18011-2018")
    end
  end

  describe "#write" do
    it "writes JSON to file" do
      Dir.mktmpdir do |dir|
        doc = Metanorma::Release::AggregatedDocument.from_h(sample_doc_h)
        params = Metanorma::Release::IndexParameters.new(
          organizations: [], channels: [], topic: "test", repo_count: 0
        )
        index = described_class.from_documents([doc], parameters: params)
        path = File.join(dir, "index.json")
        index.write(path)

        expect(File.exist?(path)).to be true
        parsed = JSON.parse(File.read(path))
        expect(parsed["version"]).to eq(1)
      end
    end
  end
end
