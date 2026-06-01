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
end
