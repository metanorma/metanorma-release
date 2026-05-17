# frozen_string_literal: true

require "tmpdir"
require "fileutils"

RSpec.describe Metanorma::Release::ContentHashChangeDetector do
  let(:tag) { "cc-18011/ed1" }

  def build_pub(dir)
    file_path = File.join(dir, "cc-18011.html")
    Metanorma::Release::Publication.new(
      identifier: "CC 18011", slug: "cc-18011", title: "Test",
      edition: "1", stage: "60", doctype: "standard", revdate: "2024-01-01",
      files: [Metanorma::Release::PublicationFile.new(format: "html", name: "cc-18011.html", path: file_path)],
      channels: ["public"], source: nil
    )
  end

  describe "#detect" do
    it "reports changed for new document" do
      dir = Dir.mktmpdir
      begin
        File.write(File.join(dir, "cc-18011.html"), "content")
        det = described_class.new(previous_releases: {})

        result = det.detect(build_pub(dir), tag)
        expect(result).to be_changed
      ensure
        FileUtils.rm_rf(dir)
      end
    end

    it "reports not changed when hashes match" do
      dir = Dir.mktmpdir
      begin
        File.write(File.join(dir, "cc-18011.html"), "content")
        hash = Metanorma::Release::ContentHash.of_directory(dir,
                                                            base: "cc-18011")
        det = described_class.new(previous_releases: { "cc-18011/ed1" => hash })

        result = det.detect(build_pub(dir), tag)
        expect(result).not_to be_changed
      ensure
        FileUtils.rm_rf(dir)
      end
    end

    it "reports changed when content differs" do
      dir = Dir.mktmpdir
      begin
        File.write(File.join(dir, "cc-18011.html"), "new content")
        old_hash = Metanorma::Release::ContentHash.from_hex("old")
        det = described_class.new(previous_releases: { "cc-18011/ed1" => old_hash })

        result = det.detect(build_pub(dir), tag)
        expect(result).to be_changed
      ensure
        FileUtils.rm_rf(dir)
      end
    end

    it "always reports changed when force is true" do
      dir = Dir.mktmpdir
      begin
        File.write(File.join(dir, "cc-18011.html"), "same content")
        hash = Metanorma::Release::ContentHash.of_directory(dir,
                                                            base: "cc-18011")
        det = described_class.new(previous_releases: { "cc-18011/ed1" => hash })

        result = det.detect(build_pub(dir), tag, force: true)
        expect(result).to be_changed
      ensure
        FileUtils.rm_rf(dir)
      end
    end
  end
end
