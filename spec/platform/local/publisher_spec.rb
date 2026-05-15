# frozen_string_literal: true

require "tmpdir"
require "fileutils"

RSpec.describe Metanorma::Release::Platform::Local::Publisher do
  let(:tmpdir) { Dir.mktmpdir }
  after { FileUtils.rm_rf(tmpdir) }

  let(:tag) { Metanorma::Release::ReleaseTag.create("cc-18011/ed1", pre_release: false) }
  let(:zip_path) { File.join(tmpdir, "source.zip") }
  let(:artifact) { Metanorma::Release::Artifact.new(zip_path: zip_path, asset_name: "cc-18011-ed1.zip", size: 100) }
  let(:metadata) { Metanorma::Release::ReleaseMetadata.new({ "id" => "cc-18011", "title" => "Test" }) }
  let(:channels) { [Metanorma::Release::Channel.public("standards")] }
  let(:output_dir) { File.join(tmpdir, "output") }

  before { File.write(zip_path, "PK fake zip content") }

  it "writes zip to output directory" do
    publisher = described_class.new(output_dir: output_dir)
    result = publisher.publish(tag, artifact, metadata, channels: channels)

    expect(File.exist?(File.join(output_dir, "cc-18011-ed1.zip"))).to be true
    expect(result).to be_created
  end

  it "writes sidecar metadata alongside zip" do
    publisher = described_class.new(output_dir: output_dir)
    publisher.publish(tag, artifact, metadata, channels: channels)

    meta_path = File.join(output_dir, "cc-18011-ed1.meta.json")
    expect(File.exist?(meta_path)).to be true
    parsed = JSON.parse(File.read(meta_path))
    expect(parsed["id"]).to eq("cc-18011")
    expect(parsed["title"]).to eq("Test")
  end

  it "creates output directory if missing" do
    nested = File.join(output_dir, "deep", "nested")
    publisher = described_class.new(output_dir: nested)
    result = publisher.publish(tag, artifact, metadata, channels: channels)

    expect(Dir.exist?(nested)).to be true
    expect(result).to be_created
  end

  it "PublishResult url is file:// URI" do
    publisher = described_class.new(output_dir: output_dir)
    result = publisher.publish(tag, artifact, metadata, channels: channels)

    expect(result.url).to start_with("file://")
    expect(result.url).to include("cc-18011-ed1.zip")
  end

  it "metadata JSON round-trips through ReleaseMetadata" do
    publisher = described_class.new(output_dir: output_dir)
    publisher.publish(tag, artifact, metadata, channels: channels)

    meta_path = File.join(output_dir, "cc-18011-ed1.meta.json")
    round_tripped = Metanorma::Release::ReleaseMetadata.from_json(File.read(meta_path))
    expect(round_tripped.id).to eq("cc-18011")
    expect(round_tripped.title).to eq("Test")
  end

  it "force_replace deletes existing file" do
    publisher = described_class.new(output_dir: output_dir)
    publisher.publish(tag, artifact, metadata, channels: channels)

    old_meta = File.join(output_dir, "cc-18011-ed1.meta.json")
    old_content = File.read(old_meta)
    expect(old_content).to include("cc-18011")

    File.write(zip_path, "PK updated content")
    result = publisher.publish(tag, artifact, metadata, channels: channels, force_replace: true)
    expect(result).to be_created

    new_zip = File.join(output_dir, "cc-18011-ed1.zip")
    expect(File.read(new_zip)).to eq("PK updated content")
  end
end
