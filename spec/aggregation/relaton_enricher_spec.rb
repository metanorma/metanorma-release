# frozen_string_literal: true

require "tmpdir"
require "json"
require "yaml"

RSpec.describe Metanorma::Release::RelatonEnricher do
  let(:fixtures_dir) { File.expand_path("../fixtures", __dir__) }
  let(:sample_rxl_path) { File.join(fixtures_dir, "rxl", "sample.rxl") }
  let(:invalid_rxl_path) { File.join(fixtures_dir, "rxl", "invalid.rxl") }

  def build_index_with_rxl(rxl_paths, output_dir)
    files = rxl_paths.map do |path|
      name = File.basename(path)
      dest = File.join(output_dir, name)
      FileUtils.cp(path, dest)
      Metanorma::Release::DocumentFile.new(name: name, path: name)
    end

    doc = Metanorma::Release::AggregatedDocument.from_h(
      "id" => "cc-18011-2018", "title" => "Test", "edition" => "1",
      "stage" => "published", "doctype" => "standard",
      "channels" => ["public/standards"], "formats" => %w[rxl],
      "flavor" => "calconnect", "contentHash" => "abc",
      "source" => { "owner" => "CalConnect", "repo" => "cc-test",
                     "tag" => "v1", "releaseUrl" => "", "releaseDate" => "" },
      "files" => files.map { |f| { "name" => f.name, "path" => f.path } }
    )
    params = Metanorma::Release::IndexParameters.new(
      organizations: ["CalConnect"], channels: [], topic: "test", repo_count: 1
    )
    Metanorma::Release::DocumentIndex.from_documents([doc], parameters: params)
  end

  def build_empty_index
    params = Metanorma::Release::IndexParameters.new(
      organizations: [], channels: [], topic: "test", repo_count: 0
    )
    Metanorma::Release::DocumentIndex.from_documents([], parameters: params)
  end

  describe "#enrich" do
    it "produces index.json and index.yaml from RXL files" do
      Dir.mktmpdir do |dir|
        index = build_index_with_rxl([sample_rxl_path], dir)
        enricher = described_class.new(registry_name: "Test Registry")

        result = enricher.enrich(index, dir, bib_dir: "relaton")

        expect(result).not_to be_nil
        expect(result.item_count).to eq(1)

        json_path = File.join(dir, "relaton", "index.json")
        yaml_path = File.join(dir, "relaton", "index.yaml")
        expect(File.exist?(json_path)).to be true
        expect(File.exist?(yaml_path)).to be true

        data = JSON.parse(File.read(json_path))
        expect(data["root"]["title"]).to eq("Test Registry")
        expect(data["root"]["items"].length).to eq(1)
        expect(data["root"]["items"].first["docidentifier"].first["content"]).to eq("CC 18011:2018")
      end
    end

    it "produces valid YAML matching JSON" do
      Dir.mktmpdir do |dir|
        index = build_index_with_rxl([sample_rxl_path], dir)
        enricher = described_class.new
        enricher.enrich(index, dir, bib_dir: "relaton")

        json_data = JSON.parse(File.read(File.join(dir, "relaton", "index.json")))
        yaml_data = YAML.unsafe_load(File.read(File.join(dir, "relaton", "index.yaml")))
        expect(yaml_data["root"]["items"].length).to eq(json_data["root"]["items"].length)
      end
    end

    it "returns nil for empty document index" do
      Dir.mktmpdir do |dir|
        enricher = described_class.new
        result = enricher.enrich(build_empty_index, dir)
        expect(result).to be_nil
      end
    end

    it "returns nil when no RXL files found" do
      Dir.mktmpdir do |dir|
        doc = Metanorma::Release::AggregatedDocument.from_h(
          "id" => "cc-18011", "title" => "No RXL", "edition" => "1",
          "stage" => "published", "doctype" => "", "channels" => [],
          "formats" => %w[html pdf], "flavor" => nil, "contentHash" => "x",
          "source" => { "owner" => "O", "repo" => "R", "tag" => "v1",
                         "releaseUrl" => "", "releaseDate" => "" },
          "files" => [{ "name" => "doc.html", "path" => "doc.html" }]
        )
        params = Metanorma::Release::IndexParameters.new(
          organizations: [], channels: [], topic: "test", repo_count: 1
        )
        index = Metanorma::Release::DocumentIndex.from_documents([doc], parameters: params)

        enricher = described_class.new
        result = enricher.enrich(index, dir)
        expect(result).to be_nil
      end
    end

    it "skips malformed RXL files without crashing" do
      Dir.mktmpdir do |dir|
        index = build_index_with_rxl([invalid_rxl_path], dir)
        enricher = described_class.new

        expect { enricher.enrich(index, dir) }.not_to raise_error
      end
    end

    it "processes valid RXL files alongside malformed ones" do
      Dir.mktmpdir do |dir|
        index = build_index_with_rxl([sample_rxl_path, invalid_rxl_path], dir)
        enricher = described_class.new

        result = enricher.enrich(index, dir, bib_dir: "relaton")

        expect(result).not_to be_nil
        expect(result.item_count).to eq(1)
      end
    end

    it "uses custom bib_dir" do
      Dir.mktmpdir do |dir|
        index = build_index_with_rxl([sample_rxl_path], dir)
        enricher = described_class.new

        result = enricher.enrich(index, dir, bib_dir: "bibliography")

        expect(result.output_dir).to eq(File.join(dir, "bibliography"))
        expect(File.exist?(File.join(dir, "bibliography", "index.json"))).to be true
      end
    end
  end

  describe "flavor handling" do
    it "auto-detects flavor from first document" do
      Dir.mktmpdir do |dir|
        index = build_index_with_rxl([sample_rxl_path], dir)
        enricher = described_class.new

        result = enricher.enrich(index, dir, bib_dir: "relaton")
        expect(result).not_to be_nil
      end
    end

    it "uses explicit flavor parameter over auto-detection" do
      Dir.mktmpdir do |dir|
        index = build_index_with_rxl([sample_rxl_path], dir)
        enricher = described_class.new(flavor: "calconnect")

        result = enricher.enrich(index, dir, bib_dir: "relaton")
        expect(result).not_to be_nil
      end
    end

    it "falls back to base Relaton::Bib::Item for unknown flavor" do
      Dir.mktmpdir do |dir|
        index = build_index_with_rxl([sample_rxl_path], dir)
        enricher = described_class.new(flavor: "unknown_flavor_xyz")

        result = enricher.enrich(index, dir, bib_dir: "relaton")
        expect(result).not_to be_nil
        expect(result.item_count).to eq(1)
      end
    end
  end

  describe "flavor registry" do
    it "has pre-registered flavors" do
      expect(described_class.flavor_registry).to include("calconnect")
      expect(described_class.flavor_registry).to include("cc")
      expect(described_class.flavor_registry).to include("iso")
    end

    it "allows registering new flavors" do
      described_class.register_flavor("test_flavor") { Relaton::Bib::Item }
      expect(described_class.flavor_registry).to include("test_flavor")
      described_class.flavor_registry.delete("test_flavor")
    end
  end
end
