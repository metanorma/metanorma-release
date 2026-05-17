# frozen_string_literal: true

require "json"

RSpec.describe Metanorma::Release::Index do
  let(:pub) do
    Metanorma::Release::Publication.new(
      identifier: "CC 18011", slug: "cc-18011", title: "Test Doc",
      edition: "1", stage: "60", doctype: "standard", revdate: "2024-01-01",
      files: [], channels: ["public"], source: nil
    )
  end

  describe ".from_documents" do
    it "creates index from publications" do
      index = described_class.from_documents([pub],
                                             parameters: { organizations: ["CC"] })
      expect(index.publications.length).to eq(1)
      expect(index.publication_count).to eq(1)
      expect(index).not_to be_empty
    end
  end

  describe "#to_h" do
    it "includes schema version, parameters, summary, documents" do
      index = described_class.from_documents([pub],
                                             parameters: { repo_count: 1 })
      h = index.to_h
      expect(h["version"]).to eq(1)
      expect(h["documents"].length).to eq(1)
      expect(h["summary"]["documentCount"]).to eq(1)
      expect(h["parameters"]["repoCount"]).to eq(1)
    end
  end

  describe "#to_json / #from_json round-trip" do
    it "round-trips through JSON" do
      source = Metanorma::Release::PublicationSource.new(
        owner: "CC", repo: "test", tag: "v1",
        url: "http://x", date: "2024-01-01"
      )
      pub_with_source = Metanorma::Release::Publication.new(
        identifier: "CC 18011", slug: "cc-18011", title: "Test",
        edition: "1", stage: "60", doctype: "standard", revdate: "2024-01-01",
        files: [], channels: ["public"], source: source
      )
      index = described_class.from_documents([pub_with_source],
                                             parameters: { repo_count: 1 })
      json = index.to_json
      parsed = described_class.from_json(json)
      expect(parsed.publication_count).to eq(1)
      expect(parsed.publications.first.slug).to eq("cc-18011")
      expect(parsed.publications.first.source.owner).to eq("CC")
    end
  end

  describe ".from_json validation" do
    it "raises on wrong schema version" do
      bad_json = JSON.generate({ "version" => 999, "documents" => [] })
      expect { described_class.from_json(bad_json) }.to raise_error(Metanorma::Release::Index::SchemaError)
    end

    it "raises on missing version" do
      bad_json = JSON.generate({ "documents" => [] })
      expect { described_class.from_json(bad_json) }.to raise_error(Metanorma::Release::Index::SchemaError)
    end

    it "raises on document missing id" do
      bad_json = JSON.generate({ "version" => 1,
                                 "documents" => [{ "title" => "no id" }] })
      expect { described_class.from_json(bad_json) }.to raise_error(Metanorma::Release::Index::SchemaError)
    end
  end

  describe "#write" do
    it "writes JSON to file" do
      dir = Dir.mktmpdir
      path = File.join(dir, "index.json")
      index = described_class.from_documents([pub], parameters: {})
      index.write(path)
      expect(File.exist?(path)).to be true
      data = JSON.parse(File.read(path))
      expect(data["version"]).to eq(1)
    ensure
      FileUtils.rm_rf(dir)
    end
  end

  describe "#channels" do
    it "returns unique sorted channels" do
      pub2 = Metanorma::Release::Publication.new(
        identifier: "CC 19060", slug: "cc-19060", title: "Test 2",
        edition: "1", stage: "60", doctype: "standard", revdate: nil,
        files: [], channels: %w[members public], source: nil
      )
      index = described_class.from_documents([pub, pub2], parameters: {})
      expect(index.channels).to eq(%w[members public])
    end
  end

  describe "#empty?" do
    it "returns true for no publications" do
      index = described_class.from_documents([], parameters: {})
      expect(index).to be_empty
    end
  end
end
