# frozen_string_literal: true

require "tmpdir"
require "fileutils"

RSpec.describe Metanorma::Release::ZipPackager do
  let(:output_dir) { Dir.mktmpdir }

  after { FileUtils.rm_rf(output_dir) }

  def build_pub(slug, files)
    pub_files = files.map do |name, content|
      path = File.join(output_dir, name)
      File.write(path, content)
      Metanorma::Release::PublicationFile.new(
        format: File.extname(name).delete_prefix("."), name: name, path: name,
      )
    end
    Metanorma::Release::Publication.new(
      identifier: slug, slug: slug, title: "Test",
      edition: "1", stage: "60", doctype: "standard", revdate: nil,
      files: pub_files, channels: ["public"], source: nil
    )
  end

  it "creates a zip with all matching files" do
    pub = build_pub("cc-18011", {
                      "cc-18011.html" => "<html/>",
                      "cc-18011.pdf" => "PDF",
                    })
    packager = described_class.new(output_dir: output_dir)
    artifact = packager.package(pub, canonical_base: "cc-18011-ed1")

    expect(File.exist?(artifact.zip_path)).to be true
    expect(artifact.asset_name).to eq("cc-18011-ed1.zip")
    expect(artifact.size).to be > 0

    require "zip"
    entries = Zip::File.open(artifact.zip_path).map(&:name)
    expect(entries).to include("cc-18011-ed1.html", "cc-18011-ed1.pdf")
  end

  it "removes stale zip before creating new one" do
    pub = build_pub("cc-18011", { "cc-18011.html" => "v1" })
    packager = described_class.new(output_dir: output_dir)
    first = packager.package(pub, canonical_base: "cc-18011-ed1")
    first_size = first.size

    build_pub("cc-18011", { "cc-18011.html" => "v2 with more content" })
    second = packager.package(pub, canonical_base: "cc-18011-ed1")

    expect(File.exist?(second.zip_path)).to be true
    expect(second.size).to be > first_size
  end

  it "resolves files against the publication base_dir in a nested site layout" do
    doc_dir = File.join(output_dir, "1.2.1", "PS")
    FileUtils.mkdir_p(doc_dir)
    %w[document.html document.xml].each do |name|
      File.write(File.join(doc_dir, name), "<doc/>")
    end
    pub = Metanorma::Release::Publication.new(
      identifier: "S-411", slug: "s-411", title: "S-411",
      edition: "1.2.1", stage: "60", doctype: "standard", revdate: nil,
      files: [
        Metanorma::Release::PublicationFile.new(format: "html", name: "document.html", path: "document.html"),
        Metanorma::Release::PublicationFile.new(format: "xml", name: "document.xml", path: "document.xml"),
      ],
      channels: ["public"], source: nil, base_dir: doc_dir
    )

    artifact = described_class.new(output_dir: output_dir)
                          .package(pub, canonical_base: "s-411-ed1.2.1")

    require "zip"
    entries = Zip::File.open(artifact.zip_path).map(&:name)
    expect(entries).to include("s-411-ed1.2.1.html", "s-411-ed1.2.1.xml")
    expect(artifact.size).to be > 22 # not an empty archive
  end

  it "fails loudly when no files resolve instead of writing an empty zip" do
    pub = Metanorma::Release::Publication.new(
      identifier: "S-999", slug: "s-999", title: "Missing",
      edition: "1", stage: "60", doctype: "standard", revdate: nil,
      files: [Metanorma::Release::PublicationFile.new(format: "html", name: "missing.html", path: "missing.html")],
      channels: ["public"], source: nil, base_dir: output_dir
    )

    expect {
      described_class.new(output_dir: output_dir)
                     .package(pub, canonical_base: "s-999-ed1")
    }.to raise_error(Metanorma::Release::ZipPackager::EmptyPackageError, /s-999/)

    expect(Dir.glob(File.join(output_dir, "*.zip"))).to be_empty
  end

  it "skips duplicate entry names instead of aborting the archive" do
    doc_dir = File.join(output_dir, "doc")
    FileUtils.mkdir_p(doc_dir)
    File.write(File.join(doc_dir, "document.html"), "<doc/>")
    File.write(File.join(doc_dir, "document.err.html"), "error report")

    pub = Metanorma::Release::Publication.new(
      identifier: "S-1", slug: "s-1", title: "S-1",
      edition: "1", stage: "60", doctype: "standard", revdate: nil,
      files: [
        Metanorma::Release::PublicationFile.new(format: "html", name: "document.html", path: "document.html"),
        Metanorma::Release::PublicationFile.new(format: "html", name: "document.err.html", path: "document.err.html"),
      ],
      channels: ["public"], source: nil, base_dir: doc_dir
    )

    artifact = described_class.new(output_dir: output_dir)
                          .package(pub, canonical_base: "s-1-ed1")

    require "zip"
    entries = Zip::File.open(artifact.zip_path).map(&:name)
    expect(entries).to eq(["s-1-ed1.html"])
  end
end
