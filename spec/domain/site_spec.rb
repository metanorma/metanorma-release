# frozen_string_literal: true

require "json"
require "tmpdir"
require "fileutils"

RSpec.describe Metanorma::Release::Site do
  let(:pub) do
    Metanorma::Release::Publication.new(
      identifier: "CC 18011", slug: "cc-18011", title: "Test Doc",
      edition: "1", stage: "60", doctype: "standard", revdate: "2024-01-01",
      files: [
        Metanorma::Release::PublicationFile.new(
          name: "cc-18011.html", format: "html", path: "cc-18011.html",
        ),
      ],
      channels: ["public"], source: nil
    )
  end

  let(:index) do
    Metanorma::Release::Index.from_documents([pub],
                                             parameters: { repo_count: 1 })
  end

  describe "#write!" do
    it "writes index.json to output_dir" do
      Dir.mktmpdir do |dir|
        site = described_class.new(index: index, output_dir: dir)
        site.write!
        index_path = File.join(dir, "index.json")
        expect(File.exist?(index_path)).to be true
        data = JSON.parse(File.read(index_path))
        expect(data["documents"].length).to eq(1)
      end
    end
  end

  describe "#enrich!" do
    it "creates relaton directory with index files" do
      Dir.mktmpdir do |dir|
        site = described_class.new(index: index, output_dir: dir)
        site.enrich!
        expect(File.exist?(File.join(dir, "relaton", "index.json"))).to be true
        expect(File.exist?(File.join(dir, "relaton", "index.yaml"))).to be true
      end
    end

    it "skips enrichment for empty index" do
      empty_index = Metanorma::Release::Index.from_documents([], parameters: {})
      Dir.mktmpdir do |dir|
        site = described_class.new(index: empty_index, output_dir: dir)
        site.enrich!
        expect(Dir.exist?(File.join(dir, "relaton"))).to be false
      end
    end
  end

  describe "#package!" do
    it "creates zip file" do
      require "zip"
      Dir.mktmpdir do |dir|
        site = described_class.new(index: index, output_dir: dir)
        site.write!
        zip_path = site.package!
        expect(File.exist?(zip_path)).to be true
        expect(zip_path).to end_with(".zip")
      end
    end

    it "accepts custom zip path" do
      require "zip"
      Dir.mktmpdir do |dir|
        site = described_class.new(index: index, output_dir: dir)
        site.write!
        custom_path = File.join(dir, "custom.zip")
        result = site.package!(zip_path: custom_path)
        expect(result).to eq(custom_path)
        expect(File.exist?(custom_path)).to be true
      end
    end
  end

  describe "display categories" do
    let(:display_categories) do
      [
        {
          "name" => "Standards, Specifications & Reports",
          "slug" => "standards",
          "doctypes" => %w[standard specification report],
        },
        {
          "name" => "Guides & Advisories",
          "slug" => "guides",
          "doctypes" => %w[guide],
        },
      ]
    end

    it "includes display_category in flattened output" do
      Dir.mktmpdir do |dir|
        site = described_class.new(index: index, output_dir: dir,
                                   data_dir: File.join(dir, "data"),
                                   display_categories: display_categories)
        site.write!
        site.enrich!
        data = JSON.parse(File.read(File.join(dir, "data", "documents.json")))
        doc = data["items"].first
        expect(doc["display_category"]).to eq("Standards, Specifications & Reports")
        expect(doc["display_category_slug"]).to eq("standards")
        expect(doc["has_html"]).to be(true)
        expect(doc["has_pdf"]).to be(false)
        expect(doc["bibliographic"]).to be_a(Hash)
      end
    end

    it "omits display_category when no display_categories provided" do
      Dir.mktmpdir do |dir|
        site = described_class.new(index: index, output_dir: dir,
                                   data_dir: File.join(dir, "data"))
        site.write!
        site.enrich!
        data = JSON.parse(File.read(File.join(dir, "data", "documents.json")))
        doc = data["items"].first
        expect(doc["display_category"]).to be_nil
        expect(doc["display_category_slug"]).to be_nil
      end
    end
  end
end
